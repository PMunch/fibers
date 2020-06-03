import macros, lists

type
  Fiber = iterator() {.closure.}
  Future[T] = ref object
    cur: Fiber
    next: ptr Fiber
    retval: T

template await(fiber: untyped): untyped =
  block:
    var fib = fiber()
    ret.next[] = fib.cur
    fib.next = ret.next
    yield
    fib.retval

macro async(procDef: untyped): untyped =
  echo procDef.treeRepr

dumpTree:
  var ret = new Future[int]
  ret.cur = iterator() =
    echo "Hello from inner fiber"
    ret.retval = 42
  return ret

proc createInner2(): Future[int] {.async.} =
  echo "Hello from inner fiber"
  return 42

proc createInner(): Future[int] =
  var ret = new Future[int]
  ret.cur = iterator() =
    echo "Hello from inner fiber"
    ret.retval = 42
  return ret

proc createAsync(): Future[string] =
  var ret = new Future[string]
  ret.cur = iterator() =
    echo "Hello from fiber"
    let retval = await createInner
    ret.retval = "All done! Result: " & $retval
  return ret

var
  fut = createAsync()
  fiberQueue = initDoublyLinkedList[Fiber]()
  fiber: Fiber
fut.next = fiber.addr
fiberQueue.append fut.cur
while fiberQueue.head != nil:
  let cur = fiberQueue.head
  fiberQueue.remove cur
  cur.value() # This runs an iteration
  if fiber != nil:
    fiberQueue.append fiber
    fiber = nil
  if not cur.value.finished:
    fiberQueue.append cur

# The return value of our future should now be set
echo fut.retval
