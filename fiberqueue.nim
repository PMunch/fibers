## This is an implementation of a fiber queue. It asserts a certain system for
## how the control flows between fibers. Essentially a fiber is ticked until it
## is completed. The "state" of the fibre is based on whether it returns
## anything, whether it has specified a following fiber, and whether or not it
## is completed. Based on this state the queue schedules the fibre differently.
## Helper templates in this module makes it easier to adhere to this system. The
## states are as follows:
##
import fibers
fiberDebug:
  import tables

template busy*(): untyped =
  assert ret.next[] == nil
  yield false

template consume*(fut: untyped): untyped =
  block:
    ret.next[] = fut.cur
    fut.next = ret.next
    yield false
    fut.retval

template await*(fiber: untyped): untyped =
  block:
    var fib = fiber()
    fib.next = ret.next
    while not fib.cur.finished():
      ret.next[] = fib.cur
      yield false
    fib.retval

template complete*(fut: untyped): untyped =
  fut.cur.finished

template produce*(value: untyped): untyped =
  ret.retval = value
  yield true

template produceFinal*(value: untyped): untyped =
  ret.retval = value
  return true

template send*(fiber, value: untyped): untyped =
  ret.next[] = fiber
  ret.retval = value
  yield true

template sendFinal*(fiber, value: untyped): untyped =
  ret.next[] = fiber
  ret.retval = value
  return true

type
  FiberNode = object
    fiber: Fiber
    blocking: seq[FiberNode]
  FiberQueue = ref object
    fibers: seq[FiberNode]
    nextFiber: Fiber
  FiberState = enum
    Busy, Waiting, Produced, Sent, Done, Superceded, Created, Returned

proc toFiberState(produced, next, finished: bool): FiberState =
  result = (finished.int shl 2).FiberState
  result = (result.int or produced.int shl 1).FiberState
  result = (result.int or next.int).FiberState

when isMainModule:
  assert toFiberState(false, false, false) == Busy
  assert toFiberState(false, false, true) == Done
  assert toFiberState(false, true, false) == Waiting
  assert toFiberState(false, true, true) == Superceded
  assert toFiberState(true, false, false) == Produced
  assert toFiberState(true, false, true) == Created
  assert toFiberState(true, true, false) == Sent
  assert toFiberState(true, true, true) == Returned

proc initFiberQueue*(): FiberQueue =
  new result

proc addFuture*[T](queue: FiberQueue, future: Future[T]) =
  future.next = queue.nextFiber.addr
  queue.fibers.add FiberNode(fiber: future.cur)

proc empty*(queue: FiberQueue): bool =
  queue.fibers.len == 0

proc tick*(queue: FiberQueue) =
  if not queue.empty:
    var cur = queue.fibers[0]
    queue.fibers.delete 0
    while cur.fiber.finished:
      cur = queue.fibers[0]
      queue.fibers.delete 0
    fiberDebug:
      echo "Ticking ", fiberNames.getOrDefault(cur.fiber.identity, "unknown")
    queue.nextFiber = nil
    let
      produced = cur.fiber()
      next = queue.nextFiber != nil
      state = toFiberState(produced, next, cur.fiber.finished)
    fiberDebug:
      echo "Fiber ", fiberNames.getOrDefault(cur.fiber.identity, "unknown"), " finished with state: ", state
    case state:
    of Busy:
      queue.fibers.add cur
    of Waiting:
      fiberDebug:
        echo "Waiting for ", fiberNames.getOrDefault(queue.nextFiber.identity, "unknown")
      let awaited = FiberNode(fiber: queue.nextFiber, blocking: @[cur])
      queue.fibers.add awaited
    of Produced:
      for node in cur.blocking:
        queue.fibers.add node
      cur.blocking = @[]
    of Sent:
      queue.fibers.add FiberNode(fiber: queue.nextFiber, blocking: @[])
      for i, node in cur.blocking:
        if node.fiber == queue.nextFiber:
          cur.blocking.delete(i)
          break
    of Done, Created:
      for node in cur.blocking:
        queue.fibers.add node
    of Superceded:
      queue.fibers.add FiberNode(fiber: queue.nextFiber, blocking: cur.blocking)
    of Returned:
      for node in cur.blocking:
        queue.fibers.add node
      queue.fibers.add FiberNode(fiber: queue.nextFiber, blocking: @[])
    fiberDebug:
      stdout.write "Fibers in queue: ["
      for i, node in queue.fibers:
        stdout.write fiberNames.getOrDefault(node.fiber.identity, "unknown")
        if i != queue.fibers.high:
          stdout.write ", "
      stdout.write "]\n"

