type
  #Future = ref object
  #  current: Test
  #  next: Test
  Test = iterator () {.closure.}
  AsyncContext = ref object
    next: Test
  Future[T] = ref object
    retval: T

proc createInner(cont: AsyncContext): Future[int] =
  var res = new Future[int]
  cont.next = iterator() =
    echo "From inner"
    res.retval = 42
    yield
    cont.next = iterator() =
      echo "From inner"
    yield
    cont.next = iterator() =
      echo "From inner"
    yield
    cont.next = iterator() =
      echo "From inner"
    yield
  return res


proc createTest(cont: AsyncContext): Future[string] =
  var res = new Future[string]
  cont.next = iterator () =
    echo "From test"
    var fut = createInner(cont)
    var next = cont.next
    while not next.finished:
      yield
    echo "Back in test, returned: ", fut.retval
    res.retval = "Return?"
  return res

import lists
var
  evQueue: DoublyLinkedList[Test]
  asyncContext = new AsyncContext
var res = asyncContext.createTest()
evQueue.append asyncContext.next
while evQueue.head != nil:
  echo "tick"
  var first = evQueue.head
  evQueue.remove first
  first.value()
  if asyncContext.next != nil:
    evQueue.append asyncContext.next
    asyncContext.next = nil
  if not first.value.finished:
    evQueue.append first

echo "Returned ", res.retval
