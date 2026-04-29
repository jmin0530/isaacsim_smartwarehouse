# Smartwarehouse

Smart warehouse simulation using **Isaac Sim**, **Docker**, and **Doosan M0609** robot.  
Isaac Sim workspace version: **5.0.0**, Python **3.10**.  

A smart warehouse simulation featuring YOLO-based object detection and robot pick-and-place manipulation.



## 목차 (Table of Contents)

- [기능 (Features)](#기능-features)
- [기술 스택 (Tech stack) 및 환경](#기술-스택tech-stack-및-환경environment)
- [시스템 구조 (System Architecture)](#시스템-구조(System-Architecture))
- [데모 영상 (demo video)](#데모-영상)
- [Troubleshooting](#Trouble-shooting)
- [Environmnet Build](#environment-build)
- [의존성 (dependencies)](#의존성-dependencies)
- [폴더 구조 (Folder Structure)](#폴더-구조-folder-structure)
- [설치 및 빌드 (Installation & Build)](#설치-및-빌드-installation--build)
- [실행 방법 (How to run)](#실행-방법-how-to-run)
- [Change Log](#change-log)
- [라이선스 (License)](#라이선스-license)



## 기능 (Features)

- YOLO-based Object Detection
- Doosan Robot Language (DRL) Control
- Isaac Sim Robot-Gripper Configuration
- Pick & Place Workflow
- Main Control Base Action


## 기술 스택(Tech stack) 및 환경(Environment)

#### 1. 운영체제 및 미들웨어 (Infrastructure)
- **OS** : Ubuntu 22.04
- **Middleware** : ROS2 Humble
- **Container** : Docker

#### 2. 시뮬레이션 및 가상 환경 (Simulation)
- **Simulator** : Isaac Sim 5.0.0
- **Robot Model** : Doosan Robot M0609
- **Gripper Model** : OnRobot RG2

#### 3. 인공지능 및 비전 (AI & Computer Vision)
- **Object Detection** : YOLOv8n
- **Vision Library** : OpenCV, PyTorch / TensorFlow

#### 4. 로봇 제어 (Control & Planning)
- **Motion Planning** : DSL
- **Language** : Python 3.10


## 시스템 구조(System Architecture)

YOLO 추론은 별도 Docker 컨테이너에서 실행되며, ROS 2 토픽으로 호스트의 메인 컨트롤러와 통신합니다.

```bash
Isaac Sim (host)
      │ /rgb  (sensor_msgs/Image)
      ▼
YOLO Detection  ──  Docker container (smartwarehouse-yolo)
                    RMW: CycloneDDS, QoS: BEST_EFFORT
      │ /yolo_labeled  (sensor_msgs/Image)
      ▼
ROS 2 Main Controller (host)
      │
      ▼
Doosan M0609 + OnRobot RG2  (via DSR API)
      │
      ▼
Pick & Place
```

상세 설계 결정은 [`docs/decisions/README.md`](docs/decisions/README.md) (ADR-002 vision-control split, ADR-003 컨테이너 DDS 설정) 참조.

## 데모 영상
![smartwarehouse Demo](docs/demo.gif)

## Troubleshooting

During development, several integration issues arose between Isaac Sim, ROS2, YOLO, and the Doosan Robot API.
These problems and their solutions are documented here:

[Troubleshooting Document](docs/TROUBLESHOOTING.md)

## Environment Build

This project required building a complete warehouse simulation environment from scratch by integrating Isaac Sim, ROS2, the Doosan Robot API, sensors, and vision systems.

The detailed process of constructing the USD scene, configuring robot and sensor communication, and setting up the training and execution environment is documented below.
[Ennvironment Document](docs/ENVIRONMENTBUILD.md)

## 의존성 (Dependencies)

#### ROS2 Packages
The following ROS2 packages are required:

```bash
sudo apt-get install \
ros-humble-gazebo-ros2-control \
ros-humble-hardware-interface-testing \
ros-humble-ament-cmake-clang-format
```
#### Python Libraries
호스트에는 별도 ML 라이브러리 설치 불필요. YOLO 추론에 필요한 의존성 (`torch`, `ultralytics`, `numpy`, `opencv-python`, `scipy`, `ros-humble-rmw-cyclonedds-cpp`)은 모두 Docker 컨테이너 내부에 격리되며, `./yolo_dockerfile/run.sh build` 시 자동 설치됩니다.

검증된 컨테이너 버전 (2026-04-29): `torch 2.11.0+cu130`, `ultralytics 8.4.42`, `numpy 2.2.6`, `cyclonedds 0.10.5`.

호스트에서 별도 학습/디버깅을 위해 ML 라이브러리가 필요하다면 (선택):
```bash
pip install numpy opencv-python torch torchvision ultralytics
```
--
## 폴더 구조 (Folder Structure)

```bash
Smartwarehouse
├── CLAUDE.md                 # 프로젝트 개요 + Hard Rules pointer + Quick Ref
├── .env.example              # 환경변수 템플릿 (ROS / YOLO / 하드웨어 게이팅)
├── .claude/                  # Claude Code 협업 인프라 (rules / agents / memory) — Claude 사용자 한정
├── config/                   # 인식 및 로봇 설정 파일 (pose.yaml 등)
├── docs/
│   ├── DEVELOPMENT_ROADMAP.md
│   ├── TROUBLESHOOTING.md
│   ├── ENVIRONMENTBUILD.md
│   ├── decisions/            # ADR-001~003 (스택 결정, vision-control split, 컨테이너 DDS 설정)
│   └── harness-tests.md      # 프로젝트 Tier 0 violation 테스트 결과
├── launch/                   # ROS 2 launch 파일 (dsr_bringup)
├── onrobot2/                 # OnRobot 그리퍼(RG2/RG6) 리소스
│   ├── meshes/               # 3D 모델 (.stl)
│   ├── urdf/                 # URDF / XACRO
│   └── onrobot/              # Isaac Sim 연동 USD
├── smartwarehouse/           # 핵심 소스 코드 (Main Logic)
│   ├── main_controller.py    # 제어 메인 루프
│   ├── base_action.py        # 로봇 기본 동작
│   ├── gripper_controller.py # OnRobot 그리퍼 제어
│   ├── yolo.py               # YOLO 검출 ROS 2 노드 (컨테이너 안에서 실행)
│   └── replicator_script.py  # Isaac Sim Replicator 데이터셋 생성
├── USD/                      # Isaac Sim 씬 (.usd)
│   ├── m0609_rg2_final.usd   # M0609 + RG2 통합 모델
│   └── smartwarehouse.usd    # 창고 환경 씬
├── yolo_dockerfile/          # YOLO 추론 컨테이너 자산
│   ├── Dockerfile            # CUDA + ROS 2 Humble + ultralytics + CycloneDDS
│   ├── entrypoint.sh         # ROS 2 setup 후 python을 bash child로 실행
│   ├── run.sh                # build / run / shell 헬퍼
│   └── install_docker.sh     # 호스트 Docker + nvidia-container-toolkit 셋업
└── best.pt                   # YOLOv8 학습 가중치
```

## 설치 및 빌드 (Installation & Build)

#### 1. 저장소 클론
```bash
git clone https://github.com/isaac-sim/IsaacSim-ros_workspaces.git
cd IsaacSim-ros_workspaces/humble/src
git clone https://github.com/DoosanRobotics/doosan-robot2.git
git clone https://github.com/jmin0530/isaacsim_smartwarehouse.git Smartwarehouse
```

#### 2. Doosan emulator install
- [doosan-robot2 git link](https://github.com/DoosanRobotics/)

#### 3. ROS 2 워크스페이스 빌드
```bash
cd ~/IsaacSim-ros_workspaces/humble_ws
rosdep install -i --from-path src --rosdistro $ROS_DISTRO -y
colcon build --packages-select smartwarehouse
source install/setup.bash
```

#### 4. Docker 호스트 셋업 (one-time)
호스트에 Docker CE + NVIDIA Container Toolkit이 필요합니다. 이미 깔려있으면 스킵.
```bash
cd ~/IsaacSim-ros_workspaces/humble_ws/src/Smartwarehouse/yolo_dockerfile
./install_docker.sh
```
스크립트가 sudo 비밀번호를 요청합니다. 끝나면 새 터미널을 열거나 `newgrp docker`로 그룹 권한을 적용하세요.

#### 5. YOLO 추론 컨테이너 이미지 빌드
```bash
./run.sh build   # 첫 빌드 ~10~15분 (cuDNN runtime + ROS 2 Humble + ultralytics)
```

## 실행 방법 (How to run)

총 4개의 터미널이 필요합니다 (Isaac Sim → DSR control → YOLO 컨테이너 → main controller).

#### 1. Isaac Sim 실행 및 프로젝트 열기
```bash
# Isaac Sim 실행
./isaacsim/isaac-sim.sh
# Isaac Sim에서 USD 파일 열기 후 Play 버튼 누르기
~/IsaacSim-ros_workspaces/humble_ws/src/Smartwarehouse/USD/smartwarehouse.usd
```

#### 2. DSR control node 실행
```bash
# 새 터미널
source ~/IsaacSim-ros_workspaces/humble_ws/install/setup.bash
source /opt/ros/humble/setup.bash
ros2 launch smartwarehouse dsr_bringup.launch.py
```

#### 3. YOLO 추론 컨테이너 실행
```bash
# 새 터미널 (호스트)
cd ~/IsaacSim-ros_workspaces/humble_ws/src/Smartwarehouse
./yolo_dockerfile/run.sh run
```
컨테이너는 `/rgb`를 구독해 추론하고 `/yolo_labeled`로 결과를 publish합니다. 인터랙티브 디버깅이 필요하면 `./yolo_dockerfile/run.sh shell`.

#### 4. Main controller 실행
```bash
# 새 터미널
source ~/IsaacSim-ros_workspaces/humble_ws/install/setup.bash
source /opt/ros/humble/setup.bash
ros2 run smartwarehouse main
```

## Change Log
- 0.1  : README edit
- 0.2  : Add gripper (OnRobot RG2) and assemble with robot arm (Doosan M0609)
- 0.3  : Make Environment (USD)
- 0.4  : ROS Setting
- 0.5  : Delete conveyor
- 0.6  : DSR Node setting
- 0.7  : DSR Node Modify
- 0.8  : DSR Test Code add
- 1.0  : Sample Code add
- 1.1  : Main Controller code add
- 1.2  : Move home code add
- 1.3  : Waypoint code add
- 1.4  : Pick2conveyor add
- 1.5  : Place2shelf add
- 1.6  : Setting TCP
- 1.7  : Find pose for pose.yaml
- 1.8  : Model direction change
- 1.9  : Robot renew
- 1.10 : Movel test clock pick and place
- 2.1  : YOLO data make with Isaac Sim Replicator
- 2.2  : Transfer replicator file to YOLO file
- 2.3  : YOLO training with Docker
- 2.4  : Test best.pt with Docker 
- 2.5  : Action test
- 2.6  : README.md update
- 2.7  : Move YOLO inference into Docker container (CycloneDDS RMW)
- 2.8  : Add project documentation and ADRs (CLAUDE.md, ROADMAP, decisions/)
- 2.9  : Add Claude Code project harness (.claude/)
- 2.10 : README update for vision-control split

## Reference
#### 참고 문헌 (Reference)
- [Doosan Robotics GitHub](https://github.com/DoosanRobotics/doosan-robot2) - 두산 로봇 ROS 2 공식 드라이버 및 DRL 가이드
- [NVIDIA Isaac Sim Docs](https://docs.isaacsim.omniverse.nvidia.com/5.0.0/index.html) - Isaac Sim 공식 문서
- [Ultralytics YOLOv8](https://github.com/ultralytics/ultralytics) - YOLOv8 모델 학습 및 추론
- [OnRobot ROS 2 Support](https://github.com/UniversalRobots/Universal_Robots_ROS2_Driver) - OnRobot 그리퍼 통합 참조

## Acknowledgements

이 프로젝트는 Doosan Robotics의 산업용 로봇 제어 언어(DRL)와 NVIDIA의 디지털 트윈 기술을 결합하여 스마트 물류 자동화 가능성을 탐색하기 위해 진행되었습니다.

도움을 준 오픈소스 커뮤니티와 관련 라이브러리 개발자분들에게 감사드립니다.

## 라이선스 (License)

MIT License © 2026 DoYoung Kim
