type
  Fiber = iterator() {.closure.}
  Future[T] = ref object
    cur: Fiber
    next: ptr Fiber
    retval: T

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
    var fib = createInner()
    ret.next[] = fib.cur
    fib.next = ret.next
    yield
    ret.retval = "All done! Result: " & $fib.retval
  return ret

import lists

var
  async = createAsync()
  fiberQueue = initDoublyLinkedList[Fiber]()
  fiber: Fiber
async.next = fiber.addr
fiberQueue.append async.cur
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
echo async.retval
