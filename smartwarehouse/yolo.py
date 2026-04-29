import os
import rclpy
import numpy as np
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
from sensor_msgs.msg import Image
from ultralytics import YOLO


SENSOR_QOS = QoSProfile(
    reliability=ReliabilityPolicy.BEST_EFFORT,
    history=HistoryPolicy.KEEP_LAST,
    depth=10,
)


class YoloNode(Node):
    def __init__(self):
        super().__init__("yolo_detector")
        weights = os.environ.get("YOLO_WEIGHTS")
        if not weights:
            raise RuntimeError("YOLO_WEIGHTS env var not set")
        self.get_logger().info(f"Loading YOLO weights: {weights}")
        self.model = YOLO(weights)

        self.rgb_sub = self.create_subscription(Image, "/rgb", self.on_rgb, SENSOR_QOS)
        self.result_pub = self.create_publisher(Image, "/yolo_labeled", SENSOR_QOS)
        self._frame_count = 0
        self.get_logger().info("subscription + publisher ready, waiting for /rgb...")

    def on_rgb(self, msg: Image):
        rgb = self._ros_to_numpy(msg)
        results = self.model(rgb, verbose=False)

        self._frame_count += 1
        if self._frame_count <= 3 or self._frame_count % 30 == 1:
            self.get_logger().info(f"frame {self._frame_count}: {len(results[0].boxes) if results else 0} detections")

        annotated = rgb.copy()
        for r in results:
            for box, conf, cls in zip(r.boxes.xyxy.tolist(),
                                     r.boxes.conf.tolist(),
                                     r.boxes.cls.tolist()):
                label = self.model.names[int(cls)]
                x1, y1, x2, y2 = map(int, box)
                self._draw_rect(annotated, x1, y1, x2, y2, color=(255, 0, 0))
                self._draw_label(annotated, x1, y1, f"{label}:{conf:.2f}")

        self._publish(annotated)

    @staticmethod
    def _ros_to_numpy(msg: Image) -> np.ndarray:
        return np.frombuffer(msg.data, dtype=np.uint8).reshape(
            (msg.height, msg.width, 3)
        )

    @staticmethod
    def _draw_rect(img, x1, y1, x2, y2, color=(255, 255, 255), thickness=1):
        img[y1:y1 + thickness, x1:x2] = color
        img[y2 - thickness:y2, x1:x2] = color
        img[y1:y2, x1:x1 + thickness] = color
        img[y1:y2, x2 - thickness:x2] = color

    @staticmethod
    def _draw_label(img, x, y, text, color=(255, 255, 255)):
        h, w = img.shape[:2]
        box_w = min(len(text) * 6, w - x)
        box_h = 10
        img[y:y + box_h, x:x + box_w] = color

    def _publish(self, np_img: np.ndarray):
        msg = Image()
        msg.header.stamp = self.get_clock().now().to_msg()
        msg.header.frame_id = "camera"
        msg.height, msg.width = np_img.shape[:2]
        msg.encoding = "rgb8"
        msg.is_bigendian = 0
        msg.step = np_img.shape[1] * 3
        msg.data = np_img.tobytes()
        self.result_pub.publish(msg)


def main(args=None):
    rclpy.init(args=args)
    node = YoloNode()
    try:
        # spin_once loop instead of rclpy.spin() — the latter fails to dispatch
        # callbacks when paired with rmw_cyclonedds_cpp + ros-humble in this image.
        while rclpy.ok():
            rclpy.spin_once(node, timeout_sec=0.1)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
