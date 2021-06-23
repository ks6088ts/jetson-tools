# https://ngc.nvidia.com/catalog/containers/nvidia:l4t-ml
DOCKER_IMAGE ?= nvcr.io/nvidia/l4t-ml:r32.5.0-py3
MOUNT_DIR ?= $(PWD)
OUTPUT_DIR ?= outputs

SSID ?= SSID
PASSWORD ?= PASSWORD
TARGET ?= graphical.target # multi-user.target

# jetson-inference
# RTSP server on Android
# 	https://play.google.com/store/apps/details?id=com.spynet.camon
INPUT_URI ?= rtsp://ks6088ts:password@192.168.3.7:8080/video/h264
OUTPUT_URI ?= display://0
INPUT_CODEC ?= h264

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
.DEFAULT_GOAL := help

.PHONY: initialize
initialize: ## initialize
	mkdir -p $(OUTPUT_DIR)

.PHONY: install-deps
install-deps: ## install dependencies
	sudo apt install -y \
		curl

.PHONY: jupyterlab
jupyterlab: ## start jupyterlab
	sudo docker pull $(DOCKER_IMAGE)
	sudo docker run \
		-it --rm \
		--runtime nvidia \
		--network host \
		--volume $(MOUNT_DIR):/home/jetson-tools \
		$(DOCKER_IMAGE)

.PHONY: install-bottom
install-bottom: ## install bottom
	curl -vvvvL \
		https://github.com/ClementTsang/bottom/releases/download/0.6.1/bottom_aarch64-unknown-linux-gnu.tar.gz \
		-o outputs/bottom.tar.gz
	cd $(OUTPUT_DIR) && tar xvf bottom.tar.gz
	# ./$(OUTPUT_DIR)/btm

.PHONY: install-jtop
install-jtop: ## install jtop
	sudo apt install -y python-pip
	sudo -H pip install jetson-stats
	sudo systemctl restart jetson_stats.service
	# sudo jtop

# https://github.com/dusty-nv/jetson-inference/blob/master/docs/building-repo-2.md#quick-reference
.PHONY: install-jetson-inference
install-jetson-inference: ## install jetson-inference
	sudo apt-get update
	sudo apt-get install -y git cmake libpython3-dev python3-numpy
	cd && git clone --recursive https://github.com/dusty-nv/jetson-inference
	cd ~/jetson-inference && \
		mkdir -p build && \
		cd build && \
		cmake ../ && \
		make -j$(nproc) && \
		sudo make install && \
		sudo ldconfig

.PHONY: set-powermode
set-powermode: ## set powermode
	sudo nvpmodel -m 0 # 0: MAXN, 1: 5W
	sudo nvpmodel -q --verbose # 確認

.PHONY: set-clocks
set-clocks: ## set clocks
	sudo jetson_clocks
	sudo jetson_clocks --show

.PHONY: set-target
set-target: ## set target mode
	systemctl get-default
	sudo systemctl set-default $(TARGET)

.PHONY: set-wifi
set-wifi: ## set wifi
	nmcli connection show
	nmcli device wifi list
	sudo nmcli device wifi connect $(SSID) password $(PASSWORD)

.PHONY: sample-cuda
sample-cuda: ## run cuda samples
	cd /usr/local/cuda-10.2/samples/5_Simulations/fluidsGL && \
	sudo make && \
	./fluidsGL

.PHONY: sample-visionworks
sample-visionworks: ## run cuda samples
	/usr/share/visionworks/sources/install-samples.sh ~/ && \
	cd ~/VisionWorks-1.6-Samples && \
	./bin/aarch64/linux/release/nvx_demo_feature_tracker -h

# https://github.com/dusty-nv/jetson-inference/blob/master/docs/imagenet-camera-2.md
.PHONY: imagenet
imagenet: ## run ImageNet
	~/jetson-inference/build/aarch64/bin/imagenet \
		$(INPUT_URI) \
		$(OUTPUT_URI) --input-codec $(INPUT_CODEC)

# https://github.com/dusty-nv/jetson-inference/blob/master/docs/detectnet-camera-2.md
.PHONY: detectnet
detectnet: ## run DetectNet
	~/jetson-inference/build/aarch64/bin/detectnet \
		$(INPUT_URI) \
		$(OUTPUT_URI) --input-codec $(INPUT_CODEC)

# https://github.com/dusty-nv/jetson-inference/blob/master/docs/detectnet-camera-2.md
# make detectnet-py INPUT_URI=rtsp://user:password@192.168.3.4:8080/video/h264 OUTPUT_URI=outputs/sample.mp4
.PHONY: detectnet-py
detectnet-py: ## run DetectNet in python
	~/jetson-inference/python/examples/detectnet.py \
		$(INPUT_URI) \
		$(OUTPUT_URI) --input-codec $(INPUT_CODEC)
