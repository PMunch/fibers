type
  Future = ref object
    current: Test
    next: Test
  Test = iterator () {.closure.}

proc createTest(): Future =
  var res = new Future
  res.current = iterator () =
    echo "From test"
    res.next = iterator() =
      echo "From inner"
    yield
    echo "Back in test"
  return res

import lists
var evQueue: DoublyLinkedList[Future]
evQueue.append createTest()
while evQueue.head != nil:
  var first = evQueue.head
  evQueue.remove first
  first.value.current()
  if not first.value.current.finished:
    if first.value.next != nil:
      evQueue.append Future(current: first.value.next)
      first.value.next = nil
    evQueue.append first

