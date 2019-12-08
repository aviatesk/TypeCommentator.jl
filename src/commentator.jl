using IRTools
using MacroTools

const ROOT_FILE = Symbol(pathof(@__MODULE__))
const _target_modules = Set{Symbol}()

struct Ctx
  typs::Set{DataType}
  f2l2t::Dict{Symbol, Dict{Int, String}} # file => line => typ map
end
Ctx(typs = [Any]) = Ctx(Set(typs), Dict())

function collectcomment!(ctx::Ctx, lin, v)::Nothing
  # only comment on specified types
  issubtype(v, ctx.typs) || return
  f = lin.file
  l = lin.line
  s = typstring(v)
  get!(ctx.f2l2t, f, Dict())[l] = s
  nothing
end

function issubtype(v, typs)
  t = typeof(v)
  any((<:).(t, typs))
end
function issubtype(tpl::Tuple, typs)
  ts = typeof.(tpl)
  any(any((<:).(t, typs)) for t in ts)
end

typstring(v) = string(typeof(v))
typstring(v::Tuple) = string("(", join(typstring.(v), ", "), ")")
typstring(v::AbstractArray) = string(typeof(v), ": ", size(v))
typstring(v::DataType) = string("DataType: ", v)

IRTools.@dynamo function (ctx::Ctx)(args...)
  ir = IRTools.IR(args...)
  ir === nothing && return

  for (v, st) in ir
    isexpr(st.expr, :call) || continue
    ir[v] = Expr(:call, IRTools.self, st.expr.args...)
  end

  m = ir.meta.method
  f = m.file
  # module validity check
  Symbol(m.module) ∉ _target_modules && return ir
  # avoid a function that @comment macro creates
  f === ROOT_FILE && return ir

  pr = IRTools.Pipe(ir)
  for (v, st) in pr
    # rules
    isexpr(st.expr, :call) && st.expr.args[2] === IRTools.var(1) && continue

    lin = pr.from.lines[st.line]
    IRTools.insertafter!(pr, v, IRTools.stmt(IRTools.xcall(TypeCommentator, :collectcomment!, IRTools.self, lin, v); line = st.line))
  end
  ir = IRTools.finish(pr)

  line = m.line - (isshortmethod(ir) ? 0 : 1)
  args = IRTools.arguments(ir)[2:end]
  for b in filter(IRTools.isreturn, IRTools.blocks(ir))
    v = IRTools.returnvalue(b)
    IRTools.push!(b, IRTools.stmt(IRTools.xcall(TypeCommentator, :summarycomment!, IRTools.self, m, line, v, args...)))
  end

  ir
end

isshortmethod(ir) = ir.meta.method.line == ir.lines[end].line

function summarycomment!(ctx::Ctx, m, l, v, args...)
  (issubtype(v, ctx.typs) || issubtype(args, ctx.typs)) || return
  argtyps = typstring(args)
  rettyp  = typstring(v)
  get!(ctx.f2l2t, m.file, Dict())[l] = string(argtyps, " -> ", rettyp)
  nothing
end
function summarycomment!(ctx::Ctx, m, l, v)
  issubtype(v, ctx.typs) || return
  rettyp = typstring(v)
  get!(ctx.f2l2t, m.file, Dict())[l] = string("() -> ", rettyp)
  nothing
end
