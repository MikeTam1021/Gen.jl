
@testset "program tagging syntaxes" begin

    @program bar(mu::Float64) begin
        @tag(normal(mu, 1), "y")
        "something"
    end

    @program foo() begin

        # untraced primitive generator invocatoin with syntax sugar
        x1 = normal(0, 1)

        # traced primitive generator invocation
        x2 = tag(Normal(), (0, 1), 2)

        # traced primitive generator invocation with syntax sugar
        x4 = @tag(normal(0, 1), 3)

        # untraced generator invocation is identical to function invocation
        x5 = bar(0.5)
        @test x5 == "something"

        # traced non-primitive generator invocation
        x6 = tag(bar, (0.5,), 6)

        # traced non-primitive generator invocation with syntax sugar
        x7 = @tag(bar(0.5), 7)
        nothing
    end

    t = ProgramTrace()
    generate!(foo, (), t)
    @test haskey(t, 2)
    @test haskey(t, 3)
    @test haskey(t, 6)
    @test haskey(t, 7)

end

@testset "program definition syntaxes" begin

    # anonymous, no arguments
    foo1 = @program () begin nothing end
    @test generate!(foo1, (), ProgramTrace()) == (0., nothing)

    # anonymous, single typed argument
    foo2 = @program (x::Int) begin x end
    @test generate!(foo2, (1,), ProgramTrace()) == (0., 1)

    # anonymous, single untyped argument
    foo3 = @program (x) begin x end
    @test generate!(foo3, (1,), ProgramTrace()) == (0., 1)

    # anonymous, multiple argument with one untyped
    foo4 = @program (x::Int, y) begin x, y end
    @test generate!(foo4, (1, 2), ProgramTrace()) == (0., (1, 2))

    # anonymous, no arguments
    @program bar1() begin nothing end
    @test generate!(bar1, (), ProgramTrace()) == (0., nothing)

    # anonymous, single typed argument
    @program bar2(x::Int) begin x end
    @test generate!(bar2, (1,), ProgramTrace()) == (0., 1)

    # anonymous, single untyped argument
    @program bar3(x) begin x end
    @test generate!(bar3, (1,), ProgramTrace()) == (0., 1)

    # anonymous, multiple argument with one untyped
    @program bar4(x::Int, y) begin x, y end
    @test generate!(bar4, (1, 2), ProgramTrace()) == (0., (1, 2))
end

@testset "program generate! syntaxes" begin

    foo = @program (x) begin x end
    
    # lower-level synyntax
    @test generate!(foo, ("asdf",), ProgramTrace()) == (0., "asdf")

    # the syntax sugar
    @test @generate!(foo("asdf"), ProgramTrace()) == (0., "asdf")
end
