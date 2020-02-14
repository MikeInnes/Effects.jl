using Effects.List, Test, FunctionalCollections

@test list() do
  x = choose(1:10)
  isodd(x) || backtrack()
  x^2
end == (1:2:9).^2

@test list() do
  x = choose([1, 2, 3])
  y = choose([1, 2, 3])
  x^2 + y == 7 || backtrack()
  (x, y)
end == [(2, 3)]

triples = list() do
  N = 20
  i = choose(1:N)
  j = choose(i:N)
  k = choose(j:N)
  i^2 + j^2 == k^2 || backtrack()
  (i, j, k)
end

@test first(triples) == (3, 4, 5)
@test length(triples) == 6

function nqueens(n)
  ps = @Persistent []
  for i = 1:n
    next = choose(1:n)
    next in ps && backtrack() # same row
    any(abs(next-p) == (i-i′) for (i′, p) in enumerate(ps)) && backtrack() # same diagonal
    ps = push(ps, next)
  end
  return ps
end

@test length(list(() -> nqueens(8))) == 92
