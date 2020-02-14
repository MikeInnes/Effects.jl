using Effects, Test
using Effects: list, choose, backtrack

@test list() do
  x = choose(1:10)
  isodd(x) || backtrack()
  x^2
end == (1:2:9).^2
