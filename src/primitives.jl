abstract Module{T}

modules = Dict{Symbol, Module}()

function register_module(name::Symbol, mod::Module)
    modules[name] = mod
end

# TODO: ARE WE RETURNING -LOG WEIGHT FOR SIMULATE OR NOT?

## TODO: should we implement custom auto-diff operators for these density functions?
## it would give an order of magnitude less AD on tape?
#
## Uniform
##function uniform_regenerate(x::Float64)
    ##x < 0 || x > 1 ? -Inf : 0.0
##end
##function uniform_simulate()
    ##rand(), 0.0
##end
##@register_module(:uniform, uniform_simulate, uniform_regenerate)
#
## Uniform continuous
#function uniform_regenerate(x::Float64, lower::Real, upper::Real)
    #x < lower || x > upper ? -Inf : -log(upper - lower)
#end
#function uniform_simulate(lower::Real, upper::Real)
    #x = rand() * (upper - lower) + lower
    #x, uniform_regenerate(x, lower, upper)
#end
##@register_module(:uniform, uniform_simulate, uniform_regenerate)
#
## Impossible (which only genreates a token 'impossible')
#type Nil
#end
#function nil_regenerate{T}(x::T)
    #x == Nil() ? 0.0 : -Inf
#end
#function nil_simulate()
    #Nil(), 0.0
#end
##@register_module(:nil, nil_simulate, nil_regenerate)
#
#
## Bernoulli
#function flip_regenerate{N}(x::Bool, p::N)
    #x ? log(p) : log(1.0 - p) # TODO use log1p?
#end
#function flip_simulate{N}(p::N)
    #x = rand() < p
    #x, flip_regenerate(x, p)
#end
##@register_module(:flip, flip_simulate, flip_regenerate)
#
## Normal
#function normal_regenerate{M,N,O}(x::M, mu::N, std::O)
    #var = std * std
    #diff = x - mu
    #-(diff * diff)/ (2.0 * var) - 0.5 * log(2.0 * pi * var)
#end
#function normal_simulate{M,N}(mu::M, std::N)
    #x = rand(Normal(concrete(mu), concrete(std)))
    #x, normal_regenerate(x, mu, std)
#end
##@register_module(:normal, normal_simulate, normal_regenerate)
#
## Gamma (k = shape, s = scale)
#function gamma_regenerate{M,N,O}(x::M, k::N, s::O)
    #(k - 1.0) * log(x) - (x / s) - k * log(s) - lgamma(k)
#end
#function gamma_simulate{M,N}(k::M, s::N) 
    #x = rand(Gamma(k, s))
    #x, gamma_regenerate(x, k, s)
#end
##@register_module(:gamma, gamma_simulate, gamma_regenerate)
#
##export @register_module
##export @register_module2
##export modules
export Module
export register_module
