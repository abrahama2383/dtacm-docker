#!/bin/sh
# Continuous SockShop traffic generator.
# Hits every service directly through the gateway so all OneAgent-instrumented
# services stay populated + healthy in Dynatrace. We drive the services directly
# because the real UI checkout is blocked by a user-service HATEOAS _links bug
# in the old dynatracesockshop images (front-end can't assemble the order).
#
# Exercises: catalogue (Go), carts (Java), user (Go), payment (Go),
#            shipping (Java) -> rabbitmq -> queue-master (Java), orders (Java).
set -u

SOCKS="3395a43e-2d88-40de-b95f-e00e1502085b 03fef6ac-1896-4ce8-bd69-b798f85c6e0b 510a0d7e-8e83-4193-b483-e27e09ddc34d 808a2de1-1aaa-4c25-a9b9-6612e8f29a38"
c() { curl -s -o /dev/null --max-time 8 "$@" 2>/dev/null; }

echo "loadgen: starting traffic loop"
i=0
while true; do
  i=$((i + 1)); S="loadgen$((i % 40))"
  c "http://catalogue/catalogue?size=5"
  c "http://catalogue/tags"
  for id in $SOCKS; do
    c "http://catalogue/catalogue/$id"
    c -X POST "http://carts/carts/$S/items" -H "Content-Type: application/json" -d "{\"itemId\":\"$id\",\"unitPrice\":15}"
  done
  c "http://carts/carts/$S/items"
  c "http://user/customers"
  c -X POST "http://payment/paymentAuth" -H "Content-Type: application/json" -d '{"amount":10.5}'
  c -X POST "http://shipping/shipping" -H "Content-Type: application/json" -d "{\"name\":\"$S\",\"itemCount\":1}"
  c "http://orders/orders"
  [ $((i % 20)) -eq 0 ] && echo "loadgen: $i iterations"
  sleep 3
done
