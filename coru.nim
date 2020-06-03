type
  Fiber = iterator() {.closure.}
  Future[T] = ref object
    cur: Fiber
    next: ptr Fiber
    retval: T

proc createInner(num: int): Future[int] =
  var ret = new Future[int]
  ret.cur = iterator() =
    echo "Hello from inner fiber: ", num
    ret.retval = 10 + num
  return ret

proc createFiber(): Future[string] =
  var ret = new Future[string]
  ret.cur = iterator() =
    echo "Hello from fiber"
    var sum = 0
    for i in 0..5:
      echo "Registering new fiber"
      # Create a new fiber
      var fib = createInner(i)
      # Tell it where to register any new fibers
      fib.next = ret.next
      # Register the fiber and yield to our caller as long as it has not completed yet
      ret.next[] = fib.cur
      while not fib.cur.finished():
        yield
      # The fiber should now have run to completion
      sum += fib.retval
    ret.retval = "All done! Result: " & $sum
  return ret

import lists

var
  async = createFiber()
  fiberQueue = initDoublyLinkedList[Fiber]()
  fiber: Fiber # This is where new fibers are registered

# Set up the registration address
async.next = fiber.addr
# Initialise our queue and start running it
fiberQueue.append async.cur
while fiberQueue.head != nil:
  let cur = fiberQueue.head
  fiberQueue.remove cur
  cur.value() # This runs an iteration
  # Add a new fiber if one was created
  if fiber != nil:
    fiberQueue.append fiber
    fiber = nil
  # If the current fiber isn't done yet, add it back to the queue
  if not cur.value.finished:
    fiberQueue.append cur

# The return value of our future should now be set
echo async.retval
