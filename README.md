# Landscape demo

This is a tiny PoC of a simple-to-deploy, small fleet Landscape demonstration.

## First principles

The core principles are:

1) Self-host landscape
  This gives us some useful performance bonuses, at the cost of requiring some
  beefy hardware.
2) Create a small fleet
  A nontrivial collection of devices performing a particular function. In this
  case, a media server-like device.
3) Manage those devices
  Showcase some useful start-to-end capabilities Landscape provides, both via
  the UI as well as scriptable or automatable API calls.

The premise of the demonstration is answering the question "how do I manage my
devices using Landscape?". This question is a challenging one which requires
a non-contrived problem set (a fleet) and a salient objective (initial
provisioning, maintenance, EoL).

## How the demo works

Execute the `demo.sh` script and provide answers to the prompts. The script will:

1) Create a local gadget snap
2) Create three Ubuntu Core images
3) Launch those three images in QEMU virtual machines
4) Create a Landscape instance in LXD
5) Magic

## Prerequisites

Have LXD installed and configured prior to executing this script.

You'll need to fetch the access-key and secret-key from the Landscape UI in
order to use the API.

Update the system-user authority to your own authority, or '*'.

## Next steps

- Improve prequisites section
    Some things require further details
- Factor out Landscape
    Ideally, Landscape is hosted on some external service (publicly exposed PS6?)
- Add snap(s) to store
    Currently the gadget is local-only
- Have prebuilt images
- More fleet examples
    microk8s/sunbeam?
        - https://canonical.com/microk8s/docs/addon-dashboard
        - https://canonical.com/microk8s/docs/add-launch-config
        - https://github.com/canonical/microk8s-content-demo-snap/tree/main
- Additional management examples
    Right now the examples are a bit trivial, ideally the examples are
    end-to-end pipeline scripts which run, report updates, share results, log
    appropriately, etc.
- Create a validation set
    Showcase managing updates via enforced validation sets.
