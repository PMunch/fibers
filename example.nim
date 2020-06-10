import fibers, fiberqueue

# This is a typical async/await pattern. We await the final value from
# createInner in createFiber.
proc createInner(): Future[int] {.fiber.} =
  echo "Hello from inner fiber"
  produce 100 # createFiber won't consume this, it awaits the final value
  produceFinal 42

proc createFiber(): Future[string] {.fiber.} =
  echo "Hello from fiber"
  var retval = await createInner # This will receive 42
  produceFinal "All done! Result: " & $retval

# This is a consumer/producer pattern. Here the producer creates many values,
# createConsumer takes a Future and tries to consume all the values from it
# before returning.
proc createProducer(): Future[int] {.fiber.} =
  echo "Hello from producer"
  for i in 1..4:
    if i != 4:
      produce i*10
    else:
      produceFinal i*10

proc createConsumer(producer: Future[int]): Future[string] {.fiber.} =
  echo "Hello from consumer"
  var retval: int
  while not producer.complete:
    retval += consume producer
    echo "Consumed: ", retval
  produceFinal "All done! Final value: " & $retval

# This is a global producer pattern. Here consumers register with the producer
# and then await its completion. The producer will send values to the consumer
# that requested them. Useful for things like a file reader.
var toGreet: seq[tuple[name: string, consumer: Fiber]]

proc createSender(): Future[string] {.fiber.} =
  echo "Hello from sender"
  var greeted = 0
  while greeted < 3:
    if toGreet.len == 0:
      busy
      continue
    toGreet[0].consumer.send "Hello " & toGreet[0].name
    toGreet.delete 0
    inc greeted

var sender = createSender()
template greet(name: string): untyped =
  block:
    toGreet.add (name, thisFiber)
    consume sender

proc createReceiver(): Future[void] {.fiber.} =
  echo greet "Peter"
  echo greet "Bob"
  echo greet "Alice"

# Create a queue and start running our fibers
var
  queue = initFiberQueue()
  fut = createFiber()
  producer = createProducer()
  consumer = createConsumer(producer)
  receiver = createReceiver()

queue.addFuture(fut) # createFiber will create the inner fiber itself
queue.addFuture(consumer) # consumer will schedule the producer, adding it manually could cause us to miss productions from it
queue.addFuture(receiver) # receiver will schedule the sender, adding it manually as well won't do any harm as we explicit register outselves so we are guaranteed to receive the productions

# As long as there are fibers in the queue we tick
while not queue.empty:
  queue.tick()

# These two fibers return something interesting
echo fut.finalValue
echo consumer.finalValue
