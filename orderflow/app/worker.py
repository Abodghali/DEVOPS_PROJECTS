import logging
import signal
import threading
from db import connect

logging.basicConfig(level=logging.INFO)
stop = threading.Event()

def process_one():
    # The lock and completion commit together. A crash rolls back the transaction.
    with connect() as conn:
        row = conn.execute("""SELECT id,quantity,unit_price_cents FROM orders
            WHERE status='pending' ORDER BY created_at LIMIT 1 FOR UPDATE SKIP LOCKED""").fetchone()
        if row is None:
            return False
        conn.execute("UPDATE orders SET status='completed', total_cents=%s, completed_at=now() WHERE id=%s",
                     (row[1] * row[2], row[0]))
    logging.info("completed order=%s", row[0])
    return True

if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: stop.set())
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    while not stop.is_set():
        try:
            if not process_one():
                stop.wait(1)
        except Exception:
            logging.exception("worker will retry after database failure")
            stop.wait(3)
