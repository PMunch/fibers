import macros, hashes, strutils

type
  Fiber* = iterator(): bool {.closure.}
  Future*[T] = ref object
    cur*: Fiber
    next*: ptr Fiber
    retval*: T
  FiberIdentity* = distinct array[2, pointer]

proc identity*(fib: Fiber): FiberIdentity =
  cast[ptr FiberIdentity](fib.unsafeAddr)[]

proc hash*(id: FiberIdentity): Hash {.borrow.}
#  hash(cast[array[2, pointer]](id))

proc `$`*(id: FiberIdentity): string =
  let twonums = cast[array[2, int]](id)
  toHex(twonums[0]) & toHex(twonums[1])

proc `==`*(x, y: FiberIdentity): bool {.borrow.}

template fiberDebug*(body: untyped): untyped =
  when defined(debugFibers):
    body

fiberDebug:
  import tables
  var fiberNames*: Table[FiberIdentity, string]

template thisFiber*(): untyped =
  ret.cur

proc finalValue*[T](fut: Future[T]): T =
  assert fut.cur.finished
  return fut.retval

template fiberImpl*(body: untyped, typ: untyped, name: string): untyped =
  var ret {.inject.} = new Future[typ]
  ret.cur = iterator(): bool =
    body
  fiberDebug:
    fiberNames[ret.cur.identity] = name
  return ret

macro fiber*(procDef: untyped): untyped =
  result = procDef
  assert $procDef[3][0][0] == "Future"
  result[6] = getAst(fiberImpl(procDef[6], procDef[3][0][1], $procDef[0]))
  echo result.repr

