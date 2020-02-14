using MacroTools

struct Effect{E}
  effect::E
  cont
end

effect(e) = error("No handler available for effect $(e).")

cps(k, ::typeof(effect), e) = Effect(e, k)

function handle(f, T, h)
  r = cps(identity, f)
  while r isa Effect && r.effect isa T
    r = h(r.effect, x -> handle(() -> r.cont(x), T, h))
  end
  return r
end

macro effect(ex)
  @capture(ex, begin x__; ((e_::T_|e_), k_) -> h_ end) ||
    error("@effect begin ...; (e, k) -> ...; end")
  quote
    local f = () -> $(esc.(x)...)
    local h = ($(esc(e)), $(esc(k))) -> $(esc(h))
    handle(f, $(esc(T)), h, )
  end
end
