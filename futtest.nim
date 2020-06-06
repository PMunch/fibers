import macros, lists, options

type
  Fiber = iterator() {.closure.}
  Future[T] = ref object
    cur: Fiber
    next: ptr Fiber
    retval: Option[T]

# Four states:
# Busy: neither next nor retval set to a value.
# Waiting: next set, but not retval. next should be completed before control returns.
# Sent: next and retval set, next should be run before control returns (but not neccesarilly completed).
# Produced: retval set, but not next. Should run anything that listened to us.

template await(fiber: untyped): untyped =
  block:
    assert ret.retval.isNone
    var fib = fiber()
    ret.next[] = fib.cur
    fib.next = ret.next
    yield
    fib.retval.get()

template produce(value: untyped): untyped =
  ret.retval = some(value)
  yield

template asyncImpl(body: untyped, typ: untyped): untyped =
  var ret {.inject.} = new Future[typ]
  ret.cur = iterator() =
    body
  return ret

macro async(procDef: untyped): untyped =
  result = procDef
  assert $procDef[3][0][0] == "Future"
  result[6] = getAst(asyncImpl(procDef[6], procDef[3][0][1]))

proc createInner(): Future[int] {.async.} =
  echo "Hello from inner fiber"
  produce 42

proc createAsync(): Future[string] {.async.} =
  echo "Hello from fiber"
  var retval = await createInner
  produce "All done! Result: " & $retval

var
  fut = createAsync()
  fiberQueue = initDoublyLinkedList[Fiber]()
  fiber: Fiber
fut.next = fiber.addr
fiberQueue.append fut.cur
while fiberQueue.head != nil:
  let cur = fiberQueue.head
  fiberQueue.remove cur
  echo "tick"
  cur.value() # This runs an iteration
  if fiber != nil:
    fiberQueue.append fiber
    fiber = nil
  if not cur.value.finished:
    fiberQueue.append cur

# The return value of our future should now be set
echo fut.retval.get()
