# Effects

```julia
] add IRTools#master
] add https://github.com/MikeInnes/Effects.jl
```

An implementation of effect handlers in Julia (aka algebraic effects, free monads etc). Effects can be used for a lot of things (continuations, exceptions, coroutines, backtracking ...). This package aims to provide a way to define effects generally, as well as important examples.

[Caveat Emptor: Julia's compiler is not designed to handle this kind of code and reserves the right to complain / be slow. Also, while everything theoretically composes nicely, this is not thoroughly tested.]

## The List Monad

The list monad allows you to write functions as if they return a single result, while actually returning all possible results.

```julia
julia> list() do
         choose(1:3)
       end
3-element Array{Int64,1}:
 1
 2
 3

julia> list() do
         (choose(1:3), choose(1:3))
       end
9-element Array{Tuple{Int64,Int64},1}:
 (1, 1)
 (1, 2)
 (1, 3)
 (2, 1)
 (2, 2)
 ...
```

You can think of `choose(xs)` as being like `rand(xs)` as `backtrack()` like `error()`. A program written like this will either one of a set of valid results, or error out. `list()` gives you the whole set in one go.

Find some Pythagorean triples:

```julia
julia> list() do
         N = 20
         i = choose(1:N)
         j = choose(i:N)
         k = choose(j:N)
         i^2 + j^2 == k^2 || backtrack()
         (i, j, k)
       end
6-element Array{Any,1}:
 (3, 4, 5)   
 (5, 12, 13)
 ...
```

This works with control flow etc. For example, we can solve the [N-queens problem](https://en.wikipedia.org/wiki/Eight_queens_puzzle) as follows:

```julia
julia> function nqueens(n)
         ps = @Persistent []
         for i = 1:n
           next = choose(1:n)
           next in ps && backtrack() # same row
           any(abs(next-p) == (i-i′) for (i′, p) in enumerate(ps)) && backtrack() # same diagonal
           ps = push(ps, next)
         end
         return ps
       end

julia> list(() -> nqueens(8))
92-element Array{Any,1}:
 [1, 5, 8, 6, 3, 7, 2, 4]
 [1, 6, 8, 3, 7, 4, 2, 5]
 [1, 7, 4, 6, 8, 2, 5, 3]
 ...
```

## Define a handler

```julia
julia> using Effects

julia> struct Flip end

julia> flip() = effect(Flip())

julia> function binary(f)
         @effect begin
           f()
           (e::Flip, k) -> max(k(true), k(false))
         end
       end

julia> binary() do
         x = flip() ? 10 : 15
         y = flip() ? 5  : 10
         x-y
       end
10
```

See also the [List implementation](src/list.jl).
