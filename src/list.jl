module List

using ..Effects

export list, choose, backtrack

struct Choose
  options
end

struct Backtrack end

choose(xs) = effect(Choose(xs))
backtrack() = effect(Backtrack())

flatmap(f, xs) = reduce(vcat, map(f, xs))

function _list(f)
  @effect begin
    f()
    (e::Union{Choose,Backtrack}, k) -> begin
      e isa Backtrack && return []
      flatmap(k, e.options)
    end
  end
end

list(f) = _list(() -> [f()])

end
