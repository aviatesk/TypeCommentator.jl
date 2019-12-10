module TypeCommentator

export @comment, stripcomments

include("commentator.jl")
include("writer.jl")

const MODSYM = Symbol(@__MODULE__)

function comment(f; mods = [:Main], typs = [Any])
  # initialize target module setting
  # NOTE: add this module so that the dynamo can recur on the anon functions that `comment` or `@comment` creates
  empty!(_TARGET_MODULE)
  push!(_TARGET_MODULE, MODSYM)
  push!(_TARGET_MODULE, mods...)

  ctx = Ctx(typs)
  ret = ctx(() -> f())

  writecomments(ctx.f2l2t)

  ret
end

macro comment(fcall, args...)
  quote
    comment(; $(map(esc, args)...)) do
      $(esc(fcall))
    end
  end
end

end # module
