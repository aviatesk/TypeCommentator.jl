const ROOT_FILE = Symbol(pathof(@__MODULE__))
const COMMENT_HEAD  = "  #:: "
const COMMENT_REGEX = r"\s\s#::\s.+$"m

fileerrormsg(path::AbstractString) = "No valid file found at $(path)"

# tries to write `text` into `p`, ensuring to keep the original text
# when the operation fails
function trywrite(p, text)
  orig = read(p)
  open(p, "w") do f
    try
      write(f, text)
    catch _
      seek(f, 0)
      write(f, orig)
      rethrow()
    end
  end
end

function writecomments(f2l2t)
  for f in keys(f2l2t)
    # NOTE: avoid anon functions that `comment` or `@comment` creates
    f === ROOT_FILE && continue
    _writecomments(f, f2l2t[f])
  end
end

_writecomments(f::Symbol, l2t) = _writecomments(string(f), l2t)
function _writecomments(p::AbstractString, l2t)
  if !isfile(p)
    @error fileerrormsg(p)
    return
  end
  text = join(map(enumerate(eachline(p))) do (l, line)
    stripcomment(line) * (haskey(l2t, l) ? COMMENT_HEAD * l2t[l] : "")
  end, '\n')
  trywrite(p, text)
end

stripcomment(line) = replace(line, COMMENT_REGEX => "")

function stripcomments(path::AbstractString)
  if !isfile(path)
    @error fileerrormsg(path)
    return
  end
  lines = collect(eachline(path; keep = true))
  text = join(stripcomment.(lines))
  trywrite(path, text)
end
