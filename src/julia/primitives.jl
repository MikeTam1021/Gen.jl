modules = Dict()
macro register_module(name, simulator, regenerator)
    if name.head != :quote error("invalid module name") end
    name = name.args[1]
    modules[name] = Pair(simulator, regenerator) # simulator returns val and log weight
    eval(quote $name = (args...) -> ($simulator)(args...)[1] end) # todo do this without killing types
end

# TODO: ARE WE RETURNING -LOG WEIGHT FOR SIMULATE OR NOT?

# TODO: should we implement custom auto-diff operators for these density functions?
# it would give an order of magnitude less AD on tape?

# Bernoulli
function flip_regenerate{N}(x::Bool, p::N)
    x ? log(p) : log(1.0 - p) # TODO use log1p?
end
function flip_simulate{N}(p::N)
    x = rand() < p
    x, flip_regenerate(x, p)
end
@register_module(:flip, flip_simulate, flip_regenerate)

# Normal
function normal_regenerate{M,N,O}(x::M, mu::N, std::O)
    var = std * std
    diff = x - mu
    - diff * diff / (2.0 * var) - 0.5 * log(2.0 * pi * var)
end
function normal_simulate{M,N}(mu::M, std::N)
    x = rand(Normal(concrete(mu), concrete(std)))
    x, normal_regenerate(x, mu, std)
end
@register_module(:normal, normal_simulate, normal_regenerate)

# Gamma (k = shape, s = scale)
function gamma_regenerate{M,N,O}(x::M, k::N, s::O)
    (k - 1.0) * log(x) - (x / s) - k * log(s) - lgamma(k)
end
function gamma_simulate{M,N}(k::M, s::N) 
    rand(Gamma(k, s))
    x, gamma_regenerate(x, k, s)
end
@register_module(:gamma, gamma_simulate, gamma_regenerate)
