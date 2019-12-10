using IRTools
using IRTools: @dynamo, IR, recurse!, self, Pipe, finish, insertafter!, stmt,
               xcall, arguments, isreturn, blocks, returnvalue
using MacroTools

# @dynamo contexts
# ----------------
struct Ctx
  typs::Set{DataType}
  f2l2t::Dict{Symbol, Dict{Int, String}} # file => line => comment map
end
Ctx(typs = [Any]) = Ctx(Set(typs), Dict())

# constants refered in the @dynamo
# --------------------------------
const _TARGET_MODULE = Set{Symbol}()

# comment on each SSA in `ir`
function add_ssacomments(ir)
  pr = Pipe(ir)
  for (v, st) in pr
    # TODO?: add special rule for some form of ssa
    lin = pr.from.lines[st.line]
    x = stmt(xcall(@__MODULE__, :ssacomment!, self, lin, v); line = st.line)
    insertafter!(pr, v, x)
  end
  finish(pr)
end

# comment on function type
function add_methodcomment!(ir)
  m = ir.meta.method
  # TODO: method calls with default arguments
  line = m.line - (isshort(ir) ? 0 : 1)
  args = arguments(ir)[2:end]
  for b in filter(isreturn, blocks(ir))
    v = returnvalue(b)
    ex = stmt(xcall(@__MODULE__, :methodcomment!, self, m, line, v, args...))
    push!(b, ex)
  end
end

isshort(ir) = ir.meta.method.line == ir.lines[end].line

# dynamo
# ------

@dynamo function (ctx::Ctx)(args...)
  ir = IR(args...)
  ir === nothing && return

  # module validity check
  # NOTE: can't comment on methods that are called from the non-targeted modules
  Symbol(ir.meta.method.module) ∉ _TARGET_MODULE && return ir

  # recursive IR manipulations
  recurse!(ir)

  ir = add_ssacomments(ir) # add comment on each SSA
  add_methodcomment!(ir)   # add comment on function type
  ir
end

# comment body
# ------------

# comment on each SSA
function ssacomment!(ctx::Ctx, lin, v)
  issubtype(v, ctx.typs) || return
  f = lin.file
  l = lin.line
  s = _comment(v)
  get!(ctx.f2l2t, f, Dict())[l] = s
  nothing
end

# comment on function type
function methodcomment!(ctx::Ctx, m, l, v, args...)
  (issubtype(v, ctx.typs) || issubtype(args, ctx.typs)) || return
  argtyps = _comment(args)
  rettyp = _comment(v)
  get!(ctx.f2l2t, m.file, Dict())[l] = string(argtyps, " -> ", rettyp)
  nothing
end
# comment on anon function type
function methodcomment!(ctx::Ctx, m, l, v)
  issubtype(v, ctx.typs) || return
  rettyp = _comment(v)
  get!(ctx.f2l2t, m.file, Dict())[l] = string("() -> ", rettyp)
  nothing
end

issubtype(v, typs) = any((<:).(typeof(v), typs))
function issubtype(tpl::Tuple, typs)
  ts = typeof.(tpl)
  any(any((<:).(t, typs)) for t in ts)
end

_comment(v) = string(typeof(v))
_comment(v::Tuple) = string("(", join(_comment.(v), ", "), ")")
_comment(v::AbstractArray) = string(typeof(v), ": ", size(v))
_comment(v::DataType) = string("DataType: ", v)
