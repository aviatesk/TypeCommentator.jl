module TypeCommentator

export @comment, stripcomments

include("commentator.jl")
include("writer.jl")

function comment(f; mods = [:Main], typs = [Any])
  empty!(_target_modules)
  push!(_target_modules, mods...)
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
