export MappedSpace

##Mapped spaces

#Typing D as Domain was causing issues

type MappedSpace{S<:FunctionSpace,D,T,DS<:Domain} <: FunctionSpace{T,DS}
    domain::D
    space::S
    MappedSpace(d::D,sp::S)=new(d,sp)
    MappedSpace(d::D)=new(d,S(canonicaldomain(d)))
    MappedSpace()=new(D(),S())
end


spacescompatible(a::MappedSpace,b::MappedSpace)=spacescompatible(a.space,b.space)&&domainscompatible(a,b)

MappedSpace{D<:Domain,T,DS<:Domain}(d::D,s::FunctionSpace{T,DS})=MappedSpace{typeof(s),D,T,DS}(d,s)

typealias IntervalMappedSpace{S,D} MappedSpace{S,D,RealBasis,Interval}
typealias PeriodicMappedSpace{S,D,T} MappedSpace{S,D,T,PeriodicInterval}

typealias LineSpace{T} IntervalMappedSpace{Chebyshev,Line{T}}
typealias PeriodicLineSpace{T} PeriodicMappedSpace{Fourier,PeriodicLine{T},RealBasis}
typealias PeriodicLineDirichlet{T} PeriodicMappedSpace{LaurentDirichlet,PeriodicLine{T},ComplexBasis}
typealias RaySpace{T} IntervalMappedSpace{Chebyshev,Ray{T}}
typealias CurveSpace{S,T,DS} MappedSpace{S,Curve{S},T,DS}
typealias OpenCurveSpace{S} CurveSpace{S,RealBasis,Interval}
typealias ClosedCurveSpace{S,T} CurveSpace{S,T,PeriodicInterval}

Space{T}(d::Line{T})=LineSpace{T}(d)
Space{T}(d::Ray{T})=RaySpace{T}(d)
#TODO: Assuming periodic is complex basis
Space{S<:PeriodicSpace}(d::Curve{S})=ClosedCurveSpace{S,ComplexBasis}(d)
Space{T}(d::PeriodicLine{T})=PeriodicLineSpace{T}(d)


domain(S::MappedSpace)=S.domain
canonicaldomain{D,S}(::Type{IntervalMappedSpace{S,D}})=Interval()
canonicaldomain{D,S}(::Type{PeriodicMappedSpace{S,D}})=Interval()
canonicaldomain{D,S,T,DS}(::Type{MappedSpace{S,D,T,DS}})=D()
canonicalspace(S::MappedSpace)=MappedSpace(S.domain,canonicalspace(S.space))

## Construction

Base.ones{T<:Number}(::Type{T},S::MappedSpace)=Fun(ones(T,S.space).coefficients,S)
transform(S::MappedSpace,vals::Vector)=transform(S.space,vals)
itransform(S::MappedSpace,cfs::Vector)=itransform(S.space,cfs)
evaluate{SS,DD,T,TT,DDS}(f::Fun{MappedSpace{SS,DD,TT,DDS},T},x)=evaluate(Fun(coefficients(f),space(f).space),tocanonical(f,x))


for op in (:(Base.first),:(Base.last))
    @eval $op{S<:MappedSpace}(f::Fun{S})=$op(Fun(coefficients(f),space(f).space))
end    



# Transform form chebyshev U series to dirichlet-neumann U series
function uneumann_dirichlet_transform{T<:Number}(v::Vector{T})
    n=length(v)
    w=Array(T,n-4)

    for k = n-4:-1:1
        sc=(3+k)*(4+k)/((-2-k)*(1+k))
        w[k]=sc*v[k+4] 
        
        if k <= n-6
            w[k]-=sc*2*(4+k)/(5+k)*w[k+2]
        end
        if k <= n-8
            w[k]+=sc*((6+k)/(4+k))*w[k+4]
        end
    end
    
    w
end


# This takes a vector in dirichlet-neumann series on [-1,1]
# and return coefficients in T series that satisfy
# (1-x^2)^2 u' = f
function uneumannrange_xsqd{T<:Number}(v::Vector{T})
    n = length(v)
    w=Array(T,n+1)
    
    for k=n:-1:1
        sc=-((16*(1+k)*(2+k))/(k*(3+k)*(4+k)))
        w[k+1]=sc*v[k]
        
        if k <= n-2
            w[k+1]-=sc*(k*(4+k))/(8(k+1))*w[k+3]
        end
        
        if k <= n-4
            w[k+1]+=sc*((k*(k+4))/(16(k+2)))*w[k+5]
        end
    end
    w[1]=zero(T)
    
    w
end




#integration functions

integrate{LS,T}(f::Fun{LineSpace{LS},T})=linsolve([ldirichlet(),Derivative()],Any[0.,f];tolerance=length(f)^2*max(1,maximum(f.coefficients))*10E-13)

function integrate{RS<:RaySpace,T}(f::Fun{RS,T})
    x=Fun(identity)
    g=fromcanonicalD(f,x)*Fun(f.coefficients)
    Fun(integrate(Fun(g,Chebyshev)).coefficients,space(f))
end


function Base.sum{LS,T}(f::Fun{LineSpace{LS},T})
    d=domain(f)
    if d.α==d.β==-.5
        sum(Fun(divide_singularity(f.coefficients),JacobiWeight(-.5,-.5,Interval())))
    else
        cf = integrate(f)
        last(cf) - first(cf)
    end
end





## identity

function identity_fun{SS,DD,DDS,DDT}(S::MappedSpace{SS,DD,DDT,DDS})
    sf=fromcanonical(S,Fun(identity,S.space))
    if isa(space(sf),JacobiWeight)
        Fun(coefficients(sf),MappedSpace(S.domain,JacobiWeight(sf.space.α,sf.space.β,S.space)))
    else
         @assert spacescompatible(space(sf),S.space)
         Fun(coefficients(sf),S)
    end
end



## Operators

function Evaluation(S1::MappedSpace,x::Bool,order::Integer)
    @assert order==0
    EvaluationWrapper(S1,x,order,Evaluation(S1.space,x,order))
end

Conversion(S1::MappedSpace,S2::MappedSpace)=ConversionWrapper(
    SpaceOperator(Conversion(S1.space,S2.space),
        S1,S2))
        
# Conversion is induced from canonical space
for OP in (:conversion_rule,:maxspace)        
    @eval function $OP(S1::MappedSpace,S2::MappedSpace)
        @assert domain(S1)==domain(S2)
        cr=$OP(S1.space,S2.space)
        MappedSpace(domain(S1),cr)
    end
end

# Multiplication is the same as unmapped space
function Multiplication{MS<:MappedSpace,T}(f::Fun{MS,T},S::MappedSpace)
    d=domain(f)
    @assert d==domain(S)
    mf=Fun(coefficients(f),space(f).space)  # project f   
    M=Multiplication(mf,S.space)
    MultiplicationWrapper(f,SpaceOperator(M,
        MappedSpace(d,domainspace(M)),
        MappedSpace(d,rangespace(M))
    ))
end


# Use tocanonicalD to find the correct derivative
function Derivative(S::MappedSpace,order::Int)
    x=Fun(identity,S)
    D1=Derivative(S.space)
    DS=SpaceOperator(D1,S,MappedSpace(domain(S),rangespace(D1)))
    M=Multiplication(Fun(tocanonicalD(S,x),S),DS|>rangespace)
    D=DerivativeWrapper(M*DS,1)
    if order==1
        D
    else
        Derivative(rangespace(D),order-1)*D
    end
end

function Derivative{T}(S::LineSpace{T},order::Int)
    d=domain(S)
    @assert d.α==-1&&d.β==-1
    x=Fun(identity,S)    
    D1=Derivative(S.space)
    DS=SpaceOperator(D1,S,MappedSpace(domain(S),rangespace(D1)))

    M1=Multiplication(Fun(1,d),Space(d))
    Mx=Multiplication(x^2,Space(d))
    M1x=M1+Mx
    u=M1x\(2/π)  #tocanonicalD(S,x)=2/π*(1/(1+x^2))

    M=Multiplication(u,DS|>rangespace)

    D=DerivativeWrapper(M*DS,1)
    
    if order==1
        D
    else
        Derivative(rangespace(D),order-1)*D
    end    
end


function Derivative{SS<:FunctionSpace}(S::MappedSpace{SS,PeriodicLine{false}},order::Int)
    d=domain(S)
    @assert d.centre==0  && d.L==1.0
    
    a=Fun([1.,0,1],PeriodicInterval())
    M=Multiplication(a,space(a))
    DS=Derivative(space(a))
    D=SpaceOperator(M*DS,S,S)
    
    if order==1
        DerivativeWrapper(D,1)
    else
        DerivativeWrapper(Derivative(rangespace(D),order-1)*D,order)
    end    
end



## CurveSpace

function evaluate{C<:CurveSpace,T}(f::Fun{C,T},x::Number)
    c=f.space
    rts=roots(domain(f).curve-x)
    @assert length(rts)==1
    evaluate(Fun(f.coefficients,c.space),first(rts))
end


identity_fun{S}(d::CurveSpace{S})=Fun(d.domain.curve.coefficients,d)

