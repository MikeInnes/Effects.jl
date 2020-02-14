using MacroTools

struct Effect{E}
  effect::E
  cont
end

effect(e) = error("No handler available for effect $(e).")

cps(k, ::typeof(effect), e) = Effect(e, k)

function handle(f, T, e)
  e.effect isa T || error("No handler available for effect $(e).")
  f(e.effect, e.cont)
end

macro effect(ex)
  @capture(ex, begin x__; ((e_::T_|e_), k_) -> h_ end) ||
    error("@effect begin ...; (e, k) -> ...; end")
  quote
    local f = () -> $(esc.(x)...)
    local h = ($(esc(e)), $(esc(k))) -> $(esc(h))
    local r = cps(identity, f)
    while r isa Effect && r.effect isa $(esc(T))
      r = h(r.effect, r.cont)
    end
    r
  end
end
