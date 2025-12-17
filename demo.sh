#!/bin/sh -eux

trap 'cleanup' EXIT INT TERM

cleanup() {
  # Kill the QEMU VMs
  # [ -z "$DEMO_PID" ] || IFS=' ' kill "$DEMO_PID"

  # Ensure the instance is stopped
  lxc stop ls-demo || true

}

destroy() {
  # Ensure the instance is stopped; remove it
  lxc stop ls-demo || true
  lxc rm ls-demo   || true

  # Remove images, built files
  rm -rf "$PWD/demo-images"
  rm -f  "$PWD/lsdemo-pc/iotdevice-lsdemo-pc.snap" \
        "${PWD}/OVMF_VARS_4M.ms.fd"*               \
        "${PWD}/OVMF_CODE_4M.secboot.fd"*          \
        "$PWD/.jwt"

  # Restore the IP in the gadget
  sed -i "s/landscape-url:.*/landscape-url: ip_placeholder/" "$PWD/lsdemo-pc/gadget.yaml"
}

# Make sure they read the README
command -v ubuntu-image >/dev/null || {
  echo "Please install ubuntu-image!"
  exit 1
}

command -v lxd >/dev/null || {
  echo "Please install and configure LXD!"
  exit 1
}

command -v qemu-system-x86_64 >/dev/null || {
  echo "Please install qemu-system-x86 and ovmf!"
  exit 1
}

[ -e "$PWD/ls-demo.assert" ] || {
  echo "Please sign the model assertion and save as ls-demo.assert!"
  exit 1
}

# copy_own copies files from a location to a location and changes ownership
copy_own() {
  src="$1"
  dest="$2"

  user="$(id -u)"

  cp -f "$src" "$dest"
  chown -f "$user":"$user" "$dest"
  chmod 644 "$dest"
}

build_gadget() {
  OLDPWD="$PWD"
  cd "$PWD/lsdemo-pc"
  snapcraft pack -o iotdevice-lsdemo-pc.snap
  cd "$OLDPWD"
}
# qemu_invoc creates a minimal QEMU VM
qemu_invoc() {
  num="$1"

  qemu-system-x86_64 -smp 1 -m 1G \
    -machine q35,smm=on           \
    -global ICH9-LPC.disable_s3=1 \
    -net nic,model=virtio         \
    -net user,hostfwd=tcp::"222${num}"-:22 \
    -drive file="$PWD/demo-images/pc-${num}.img",if=none,format=raw,id=disk1 \
    -drive file="${PWD}/OVMF_CODE_4M.secboot.fd-${num}",if=pflash,format=raw,unit=0,readonly=on \
    -drive file="${PWD}/OVMF_VARS_4M.ms.fd-${num}",if=pflash,format=raw,unit=1 \
    -device virtio-blk-pci,drive=disk1,bootindex=1 -serial mon:stdio
}

ls_init() {
  lxc launch ubuntu:24.04 ls-demo

  # Wait for container to appear
  sleep 5
  ls_demo_ip="$(lxc ls -c4 --format csv ls-demo | awk '{print $1}')"

  lxc exec ls-demo -- sudo apt update
  lxc exec ls-demo -- sudo apt install -y ca-certificates software-properties-common
  lxc exec ls-demo -- sudo hostnamectl set-hostname "ls-demo"
  lxc exec ls-demo -- sudo add-apt-repository -y ppa:landscape/self-hosted-24.04
  lxc exec ls-demo -- sudo apt update
  lxc exec ls-demo -- sudo DOMAIN="$ls_demo_ip" DEBIAN_FRONTEND=noninteractive apt install -y landscape-server-quickstart

  sed -i "s/ip_placeholder/$ls_demo_ip/" "$PWD/lsdemo-pc/gadget.yaml"

  echo "Landscape UI should be available at ${ls_demo_ip}:80"
  echo "Please navigate to http://${ls_demo_ip}:80 to provision the admin"
}

image_setup() {
  ubuntu-image snap \
    -O demo-images/ \
    --snap "$PWD/lsdemo-pc/iotdevice-lsdemo-pc.snap" \
    "$PWD/ls-demo.assert"
  
  mv -f "$PWD/demo-images/pc.img" "$PWD/demo-images/vanilla-pc.img"
  copy_own "$PWD/demo-images/vanilla-pc.img" "$PWD/demo-images/pc-1.img"
  copy_own "$PWD/demo-images/vanilla-pc.img" "$PWD/demo-images/pc-2.img"
  copy_own "$PWD/demo-images/vanilla-pc.img" "$PWD/demo-images/pc-3.img"
}

main() {
  # A weak check to see if we've got landscape setup
  lxc ls --format csv | grep ls-demo || ls_init
  lxc start ls-demo || true
  
  [ -e "$PWD/lsdemo-pc/iotdevice-lsdemo-pc.snap" ] || build_gadget
  [ -e "$PWD/demo-images/vanilla-pc.img" ]         || image_setup
  
  # Some useful variables
  OVMF_MS=/usr/share/OVMF/OVMF_VARS_4M.ms.fd
  OVMF_SB=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd
  
  DEMO_PIDS=
  for num in 1 2 3; do
    [ -e "$PWD/${OVMF_MS##*/}-${num}" ] || copy_own "$OVMF_MS" "$PWD/${OVMF_MS##*/}-${num}"
    [ -e "$PWD/${OVMF_SB##*/}-${num}" ] || copy_own "$OVMF_SB" "$PWD/${OVMF_SB##*/}-${num}"
    qemu_invoc "$num" & DEMO_PIDS="$DEMO_PIDS $!"
  done
  
  # Sleep for hour increments
  while :; do sleep 3600; done
}

"$@"
