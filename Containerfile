# A custom Bazzite image for the ASUS ROG Flow Z13 (2025, GZ302EA — Strix Halo).
#
# How this works, in one paragraph: Bazzite is an image-based OS. Your system files are
# read-only and arrive as one tested image, like an app update. So instead of changing the
# system by hand, you describe the changes here, GitHub builds a new image from them, and your
# machine switches to it. The previous image stays on disk, so a bad build is one reboot away
# from being undone.

# 1. Start from stock Bazzite. Everything Bazzite gives you comes along for free.
FROM ghcr.io/ublue-os/bazzite-dx-gnome:stable

# 2. Bake in the fixes and tools this tablet needs (see scripts/ for what each one does).
COPY scripts/lightbar /usr/bin/lightbar
COPY scripts/gz302ea-lightbar-reset.sh /usr/bin/gz302ea-lightbar-reset.sh
COPY scripts/gz302ea-lightbar-reset.service /etc/systemd/system/gz302ea-lightbar-reset.service
COPY scripts/bluetooth-poweron.service /etc/systemd/system/bluetooth-poweron.service
COPY scripts/bt-auto-reconnect.sh /usr/bin/bt-auto-reconnect.sh
COPY scripts/bt-auto-reconnect.service /etc/systemd/system/bt-auto-reconnect.service
COPY scripts/99-gz302ea-rgb.rules /etc/udev/rules.d/99-gz302ea-rgb.rules
COPY scripts/99-bt-nosuspend.rules /etc/udev/rules.d/99-bt-nosuspend.rules
COPY scripts/mt7925e.conf /etc/modprobe.d/mt7925e.conf
COPY scripts/btusb.conf /etc/modprobe.d/btusb.conf
COPY scripts/usb-wakeup-fix /usr/lib/systemd/system-sleep/usb-wakeup-fix
COPY scripts/gz302ea-sensors.conf /etc/sensors.d/gz302ea.conf

# 3. ASUS hardware control (fans, power profiles, keyboard) from the asus-linux project,
#    plus Bluetooth that powers on at boot and keeps reconnecting dropped devices.
RUN curl -Lo /etc/yum.repos.d/asus-linux.repo \
    https://copr.fedorainfracloud.org/coprs/lukenukem/asus-linux/repo/fedora-$(rpm -E %fedora)/lukenukem-asus-linux-fedora-$(rpm -E %fedora).repo

RUN rpm-ostree install \
    asusctl \
    asusctl-rog-gui \
    && rpm-ostree cleanup -m \
    && chmod +x /usr/bin/lightbar /usr/bin/gz302ea-lightbar-reset.sh \
                /usr/lib/systemd/system-sleep/usb-wakeup-fix /usr/bin/bt-auto-reconnect.sh \
    && sed -i 's/^#AutoEnable=true/AutoEnable=true/' /etc/bluetooth/main.conf \
    && sed -i 's/^#Privacy = off/Privacy = device/' /etc/bluetooth/main.conf \
    && sed -i 's/^#ReconnectUUIDs=.*/ReconnectUUIDs=00001112-0000-1000-8000-00805f9b34fb,0000111f-0000-1000-8000-00805f9b34fb,0000110a-0000-1000-8000-00805f9b34fb,0000110b-0000-1000-8000-00805f9b34fb,00001812-0000-1000-8000-00805f9b34fb/' /etc/bluetooth/main.conf \
    && sed -i 's/^#ReconnectAttempts=7/ReconnectAttempts=15/' /etc/bluetooth/main.conf \
    && sed -i 's/^#ReconnectIntervals=1,2,4,8,16,32,64/ReconnectIntervals=1,2,4,8,16,32,64/' /etc/bluetooth/main.conf \
    && systemctl enable asusd.service \
    && systemctl enable gz302ea-lightbar-reset.service \
    && systemctl enable bluetooth-poweron.service \
    && systemctl enable bt-auto-reconnect.service \
    && ostree container commit

# 4. z13ctl — RGB, fan and TDP control built specifically for this tablet
#    (https://github.com/dahui/z13ctl). A static binary, so nothing to layer.
RUN curl -fsSL https://github.com/dahui/z13ctl/releases/download/v1.1.6/z13ctl_1.1.6_linux_amd64.tar.gz \
    | tar xz -C /tmp z13ctl \
    && install -m 0755 /tmp/z13ctl /usr/bin/z13ctl \
    && rm -f /tmp/z13ctl \
    && ostree container commit


# 5. Howdy — facial recognition for PAM authentication.
# Install build dependencies and Python packages first, then verify dlib
# using the exact interpreter that the Howdy launcher invokes.

# Install build dependencies and Python packages into the immutable /usr tree.
RUN dnf install -y \
      python3-devel \
      python3-pip \
      python3-setuptools \
      python3-wheel \
      cmake \
      gcc \
      gcc-c++ \
      make \
      meson \
      ninja-build \
      opencv-devel \
      python3-opencv \
      pam-devel \
      inih-devel \
      libevdev-devel \
      libv4l-devel \
      wget \
      bzip2 \
      git && \
    /usr/bin/python -m pip install --no-cache-dir --prefix=/usr dlib elevate && \
    /usr/bin/python -m pip show dlib && \
    /usr/bin/python -c "import dlib; print('dlib version:', dlib.__version__)" && \
    /usr/bin/python -c "import cv2; print('OpenCV version:', cv2.__version__)" && \
    ostree container commit

# Download, compile, and install Howdy separately.
RUN git clone --depth=1 https://github.com/boltgolt/howdy.git /tmp/howdy-src && \
    meson setup --prefix=/usr /tmp/howdy-src/build /tmp/howdy-src && \
    meson compile -C /tmp/howdy-src/build && \
    meson install -C /tmp/howdy-src/build && \
    rm -rf /tmp/howdy-src && \
    ostree container commit

# Download and install the pretrained dlib models required by Howdy
RUN cd /usr/share/dlib-data && \
    bash ./install.sh && \
    test -s shape_predictor_5_face_landmarks.dat && \
    test -s mmod_human_face_detector.dat && \
    test -s dlib_face_recognition_resnet_model_v1.dat && \
    ostree container commit

