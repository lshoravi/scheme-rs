(import (rnrs) (test) (only (threads) spawn join) (only (async) sleep))

;; sleep from (async) suspends on a tokio timer, so these force real
;; Poll::Pending round-trips instead of first-poll completion.

;; Through Handle::block_on in a spawned OS thread.
(let ((h (spawn (lambda () (sleep 5) 'woke))))
  (assert-equal? (join h) 'woke))

;; Through the park-based block_on, on a non-worker OS thread (the only
;; place call_sync is still reached now that hashtable callbacks are async).
(assert-equal? (call-sync-in-thread (lambda () (sleep 5) 'parked)) 'parked)
