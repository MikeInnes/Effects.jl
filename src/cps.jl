using IRTools
using IRTools: IR, Variable, Statement, Lambda, @dynamo, functional, cond,
  argument!, arguments, isexpr, stmt, xcall, return!, returnvalue

struct Func
  f # Avoid over-specialising on the continuation object.
end

(f::Func)(args...) = f.f(args...)

function captures(ir, vs)
  us = Set()
  for v in vs
    isexpr(ir[v].expr) || continue
    foreach(x -> x isa Variable && push!(us, x), ir[v].expr.args)
  end
  push!(us, returnvalue(IRTools.block(ir, 1)))
  return setdiff(us, vs)
end

rename(env, x) = x
rename(env, x::Variable) = env[x]
rename(env, x::Expr) = Expr(x.head, rename.((env,), x.args)...)
rename(env, x::Statement) = stmt(x, expr = rename(env, x.expr))

excluded = [GlobalRef(Base, :getindex)]

function continuation!(bl, ir, env, vs, ret)
  rename(x) = Effects.rename(env, x)
  local v, st
  while true
    isempty(vs) && return return!(bl, rename(Expr(:call, ret, returnvalue(IRTools.block(ir, 1)))))
    v = popfirst!(vs)
    st = ir[v]
    isexpr(st.expr, :call) && !(st.expr.args[1] ∈ excluded) && break
    isexpr(st.expr, :lambda) &&
      (st = stmt(st, expr = Expr(:lambda, cpslambda(st.expr.args[1]), st.expr.args[2:end]...)))
    env[v] = push!(bl, rename(st))
  end
  cs = [ret, setdiff(captures(ir, vs), [v])...]
  next = push!(bl, Expr(:lambda, continuation(ir, vs, cs, v, ret), rename.(cs)...))
  next = xcall(Effects, :Func, next)
  ret = push!(bl, stmt(st, expr = xcall(Effects, :cps, next, rename(st.expr).args...)))
  return!(bl, ret)
end

function continuation(ir, vs, cs, in, ret)
  bl = empty(ir)
  env = Dict()
  self = argument!(bl)
  env[in] = argument!(bl)
  for (i, c) in enumerate(cs)
    env[c] = pushfirst!(bl, xcall(:getindex, self, i))
  end
  continuation!(bl, ir, env, vs, ret)
end

cpslambda(ir) = cpstransform(ir, true)

function cpstransform(ir, lambda = false)
  lambda || (ir = functional(ir))
  k = argument!(ir, at = lambda ? 2 : 1)
  bl = empty(ir)
  env = Dict()
  for arg in arguments(ir)
    env[arg] = argument!(bl)
  end
  continuation!(bl, ir, env, keys(ir), k)
end

cps_lambda(f::Lambda{S,I}, k) where {S,I} =
  Lambda{S,I}(x -> cps(k, first(f.data), x), Base.tail(f.data)...)

cps(k, f::IRTools.Lambda{<:Tuple{typeof(cps),Vararg{Any}}}, args...) = f(k, args...)
cps(k, f::Func, args...) = cps_lambda(f.f, k)(args...)

cps(k, f::Core.IntrinsicFunction, args...) = k(f(args...))
cps(k, ::typeof(Core._apply), f, args...) = Core._apply(cps, (k, f), args...)
cps(k, ::typeof(cond), c, t, f) = c ? cps(k, t) : cps(k, f)
cps(k′, ::typeof(cps), k, args...) = cps(x -> cps(k′, k, x), args...)

for f in :[getfield, typeof, Core.apply_type, typeassert, (===), ifelse,
           Core.sizeof, Core.arrayset, tuple, isdefined, fieldtype, nfields,
           isa, Core.arraysize, repr, print, println, Base.vect, Broadcast.broadcasted,
           Broadcast.materialize, Core.Compiler.return_type, Base.union!, Base.getindex, Base.haskey,
           Base.pop!, Base.setdiff].args
  @eval cps(k, ::typeof($f), args...) = k($f(args...))
end

@dynamo function cps(k, f, args...)
  ir = IR(f, args...)
  ir == nothing && error("No IR for $((f, args...))")
  cpstransform(ir)
end
