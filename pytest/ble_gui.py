import sys
import csv
import time
import struct
import asyncio
from dataclasses import dataclass
from typing import Optional, Dict, Any, List

from PySide6 import QtCore, QtWidgets
import pyqtgraph as pg

from bleak import BleakClient
from qasync import QEventLoop, asyncSlot


# =======================
# CONFIG: fill these in
# =======================
ADDRESS = "E2:89:6D:EC:FB:97"
NOTIFY_UUID = "12345678-1234-1234-1234-1234567890AC"
WRITE_UUID = "12345678-1234-1234-1234-1234567890AD"

OUT_CSV = "ble_decoded.csv"
# =======================


def t_now_s() -> float:
    return time.perf_counter()


# -----------------------
# IMPORTANT: Decoder
# -----------------------
# Edit this to match YOUR packet format.
# Below is a common example:
# 14 bytes total:
#   uint16 seq
#   int16 ax, ay, az
#   int16 gx, gy, gz
# => 2 + 12 = 14
#
# If your packet differs, change PACK_FMT and field names.
PACK_FMT = "<H6h"
FIELDS = ["seq", "ax", "ay", "az", "gx", "gy", "gz"]

# Example scaling (adjust to your IMU setup if you want real units)
# ax/ay/az are in milli-g  => convert to g
ACC_SCALE = 1.0 / 1000.0

# gx/gy/gz are in centi-deg/s => convert to deg/s
GYR_SCALE = 1.0 / 100.0



def decode_packet(b: bytes) -> Dict[str, Any]:
    if len(b) < struct.calcsize(PACK_FMT):
        raise ValueError(f"Packet too short: {len(b)} bytes")

    vals = struct.unpack(PACK_FMT, b[: struct.calcsize(PACK_FMT)])
    d = dict(zip(FIELDS, vals))

    # Optional scaling
    for k in ["ax", "ay", "az"]:
        d[k] = d[k] * ACC_SCALE
    for k in ["gx", "gy", "gz"]:
        d[k] = d[k] * GYR_SCALE

    return d


@dataclass
class Sample:
    t_s: float
    data: Dict[str, Any]


class BleWorker(QtCore.QObject):
    sample_received = QtCore.Signal(object)   # emits Sample
    status = QtCore.Signal(str)
    connected_changed = QtCore.Signal(bool)

    def __init__(self):
        super().__init__()
        self._client: Optional[BleakClient] = None
        self._running = False

    async def ble_connect(self):
        if self._client and self._client.is_connected:
            return

        self.status.emit("Connecting...")
        self._client = BleakClient(ADDRESS, timeout=20.0)

        try:
            await self._client.connect()
        except Exception as e:
            self._client = None
            self.connected_changed.emit(False)
            self.status.emit(f"Connect error: {e}")
            raise

        self.connected_changed.emit(True)
        self.status.emit("Connected.")


    async def ble_disconnect(self):
        self._running = False
        if self._client:
            try:
                if self._client.is_connected:
                    await self._client.disconnect()
            finally:
                self.connected_changed.emit(False)
                self.status.emit("Disconnected.")

    async def start_notify(self):
        if not self._client or not self._client.is_connected:
            await self.ble_connect()

        if not self._client:
            raise RuntimeError("BLE client is None after connect (unexpected).")

        services = self._client.services

        # If empty, wait a moment (Windows sometimes delays GATT cache load)
        if not services:
            await asyncio.sleep(0.5)
            services = self._client.services


        if services:
            found = False
            for s in services:
                for ch in s.characteristics:
                    if ch.uuid.lower() == NOTIFY_UUID.lower():
                        found = True
                        break
                if found:
                    break
            if not found:
                raise RuntimeError(f"Notify characteristic not found: {NOTIFY_UUID}")

        self._running = True

        def handler(_char, data: bytearray):
            if not self._running:
                return
            ts = t_now_s()
            try:
                decoded = decode_packet(bytes(data))
                self.sample_received.emit(Sample(ts, decoded))
            except Exception as e:
                self.status.emit(f"Decode error: {e} (len={len(data)})")

        self.status.emit("Starting notifications...")
        await self._client.start_notify(NOTIFY_UUID, handler)
        self.status.emit("Notifications ON.")


    async def stop_notify(self):
        self._running = False
        if self._client and self._client.is_connected:
            try:
                await self._client.stop_notify(NOTIFY_UUID)
            except Exception:
                pass
        self.status.emit("Notifications OFF.")

    async def _get_client(self) -> BleakClient:

        if self._client is None:
            await self.ble_connect()

        if self._client is None or not self._client.is_connected:
            raise RuntimeError("BLE not connected.")

        return self._client


    async def _ensure_connected(self):
        if not self._client or not self._client.is_connected:
            await self.ble_connect()
        if not self._client:
            raise RuntimeError("BLE client is None (unexpected).")
    
    async def send_cmd_stop(self):
        client = await self._get_client()
        self.status.emit("Sending STOP (0x00)...")
        await client.write_gatt_char(WRITE_UUID, bytes([0x00]), response=True)
        self.status.emit("STOP sent.")

    async def send_cmd_start(self):
        client = await self._get_client()
        self.status.emit("Sending START (0x01)...")
        await client.write_gatt_char(WRITE_UUID, bytes([0x01]), response=True)
        self.status.emit("START sent.")

    async def send_cmd_reset_seq(self):
        client = await self._get_client()
        self.status.emit("Sending RESET SEQ (0x02)...")
        await client.write_gatt_char(WRITE_UUID, bytes([0x02]), response=True)
        self.status.emit("RESET sent.")





class MainWindow(QtWidgets.QMainWindow):
    def __init__(self, loop: asyncio.AbstractEventLoop):
        super().__init__()
        self.loop = loop
        self.setWindowTitle("BLE IMU Live Viewer (decoded)")
        self.resize(1000, 650)

        self.worker = BleWorker()
        self.worker.sample_received.connect(self.on_sample)
        self.worker.status.connect(self.on_status)
        self.worker.connected_changed.connect(self.on_connected)

        # ---- UI layout ----
        central = QtWidgets.QWidget()
        self.setCentralWidget(central)
        layout = QtWidgets.QVBoxLayout(central)

        # Controls
        row = QtWidgets.QHBoxLayout()
        layout.addLayout(row)

        self.btn_connect = QtWidgets.QPushButton("Connect")
        self.btn_start = QtWidgets.QPushButton("Start (0x01)")
        self.btn_stop = QtWidgets.QPushButton("Stop (0x00)")
        self.btn_reset = QtWidgets.QPushButton("Reset Seq (0x02)")
        self.btn_disconnect = QtWidgets.QPushButton("Disconnect")

        row.addWidget(self.btn_connect)
        row.addWidget(self.btn_start)
        row.addWidget(self.btn_stop)
        row.addWidget(self.btn_reset)
        row.addWidget(self.btn_disconnect)

        self.lbl_status = QtWidgets.QLabel("Idle.")
        row.addWidget(self.lbl_status, stretch=1)

        # Table
        self.table = QtWidgets.QTableWidget(0, 2)
        self.table.setHorizontalHeaderLabels(["Field", "Value"])
        self.table.horizontalHeader().setStretchLastSection(True)
        layout.addWidget(self.table, stretch=1)

        # ---- Plots (split: Accel + Gyro) ----
        self.plotA = pg.PlotWidget(title="Acceleration (A)")
        self.plotA.addLegend()
        self.plotA.setLabel("bottom", "samples")
        layout.addWidget(self.plotA, stretch=2)

        self.plotG = pg.PlotWidget(title="Gyroscope (G)")
        self.plotG.addLegend()
        self.plotG.setLabel("bottom", "samples")
        layout.addWidget(self.plotG, stretch=2)

        # Buffers
        self.max_points = 300
        self.buffersA: Dict[str, List[float]] = {"ax": [], "ay": [], "az": []}
        self.buffersG: Dict[str, List[float]] = {"gx": [], "gy": [], "gz": []}

        pens = {
            "x": pg.mkPen("r", width=2),
            "y": pg.mkPen("g", width=2),
            "z": pg.mkPen("b", width=2),
        }

        self.curvesA = {
            "ax": self.plotA.plot([], [], name="ax", pen=pens["x"]),
            "ay": self.plotA.plot([], [], name="ay", pen=pens["y"]),
            "az": self.plotA.plot([], [], name="az", pen=pens["z"]),
        }
        self.curvesG = {
            "gx": self.plotG.plot([], [], name="gx", pen=pens["x"]),
            "gy": self.plotG.plot([], [], name="gy", pen=pens["y"]),
            "gz": self.plotG.plot([], [], name="gz", pen=pens["z"]),
        }

        # CSV logging
        self._csv_f = open(OUT_CSV, "w", newline="")
        self._csv_w = csv.writer(self._csv_f)
        self._csv_w.writerow(["t_s"] + FIELDS)
        self._csv_f.flush()

        # Initialize table rows
        self.field_rows = {}
        self.table.setRowCount(len(FIELDS))
        for i, k in enumerate(FIELDS):
            self.table.setItem(i, 0, QtWidgets.QTableWidgetItem(k))
            self.table.setItem(i, 1, QtWidgets.QTableWidgetItem(""))
            self.field_rows[k] = i

        # Wire buttons
        self.btn_connect.clicked.connect(self.connect_clicked)
        self.btn_start.clicked.connect(self.start_clicked)
        self.btn_stop.clicked.connect(self.stop_clicked)
        self.btn_reset.clicked.connect(self.reset_clicked)
        self.btn_disconnect.clicked.connect(self.disconnect_clicked)

        self.on_connected(False)

    def closeEvent(self, event):
        try:
            self._csv_f.close()
        except Exception:
            pass
        self.loop.create_task(self.worker.ble_disconnect())
        super().closeEvent(event)

    def on_status(self, msg: str):
        self.lbl_status.setText(msg)

    def on_connected(self, connected: bool):
        self.btn_connect.setEnabled(not connected)
        self.btn_disconnect.setEnabled(connected)
        self.btn_start.setEnabled(connected)
        self.btn_stop.setEnabled(connected)
        self.btn_reset.setEnabled(connected)

    @asyncSlot()
    async def connect_clicked(self):
        try:
            await self.worker.ble_connect()
        except Exception as e:
            self.on_status(f"Connect failed: {e}")

    @asyncSlot()
    async def start_clicked(self):
        try:
            # Send 0x01 to start streaming, then ensure notify is on
            await self.worker.send_cmd_start()
            await self.worker.start_notify()
        except Exception as e:
            self.on_status(f"Start failed: {e}")

    @asyncSlot()
    async def stop_clicked(self):
        try:
            # Send 0x00 to stop streaming (leave notify subscribed; device just stops sending)
            await self.worker.send_cmd_stop()
        except Exception as e:
            self.on_status(f"Stop failed: {e}")

    @asyncSlot()
    async def reset_clicked(self):
        try:
            # Send 0x02 to reset seq number
            await self.worker.send_cmd_reset_seq()
        except Exception as e:
            self.on_status(f"Reset failed: {e}")

    @asyncSlot()
    async def disconnect_clicked(self):
        await self.worker.ble_disconnect()

    @QtCore.Slot(object)
    def on_sample(self, sample: Sample):
        # update table (safe)
        for k, v in sample.data.items():
            r = self.field_rows.get(k)
            if r is None:
                continue
            item = self.table.item(r, 1)
            if item is None:
                item = QtWidgets.QTableWidgetItem("")
                self.table.setItem(r, 1, item)
            item.setText(str(v))

        # write CSV
        row = [f"{sample.t_s:.6f}"] + [sample.data.get(k, "") for k in FIELDS]
        self._csv_w.writerow(row)
        self._csv_f.flush()

        # ---- Update Accel buffers ----
        for k in ["ax", "ay", "az"]:
            val = sample.data.get(k)
            if val is None:
                continue
            buf = self.buffersA[k]
            buf.append(float(val))
            if len(buf) > self.max_points:
                del buf[: len(buf) - self.max_points]

        # ---- Update Gyro buffers ----
        for k in ["gx", "gy", "gz"]:
            val = sample.data.get(k)
            if val is None:
                continue
            buf = self.buffersG[k]
            buf.append(float(val))
            if len(buf) > self.max_points:
                del buf[: len(buf) - self.max_points]

        # ---- Redraw Accel ----
        nA = max((len(b) for b in self.buffersA.values()), default=0)
        xsA = list(range(nA))
        for k, curve in self.curvesA.items():
            ys = self.buffersA[k]
            curve.setData(xsA[-len(ys):], ys)

        # ---- Redraw Gyro ----
        nG = max((len(b) for b in self.buffersG.values()), default=0)
        xsG = list(range(nG))
        for k, curve in self.curvesG.items():
            ys = self.buffersG[k]
            curve.setData(xsG[-len(ys):], ys)


def main():
    app = QtWidgets.QApplication(sys.argv)
    loop = QEventLoop(app)
    asyncio.set_event_loop(loop)

    w = MainWindow(loop)
    w.show()

    with loop:
        loop.run_forever()


if __name__ == "__main__":
    main()
