#!/Users/aiguofer/.pyenv/versions/default/bin/python
"""
Yabaictl is a wrapper around yabai to accomplish:

 - Use 'static' workspaces by using labels s1, s2,...,s10
 - Reference displays numeriaclly starting at 1 on the far left
   regardless of which is the main display (order is customizable
   in setups var)
 - Distribute static workspaces evenly across displays, for example
   with 3 displays:
   |------------|--------|--------|
   |     D1     |   D2   |   D3   |
   |s1,s4,s7,s10|s2,s5,s8|s3,s6,s9|
   |------------|--------|--------|
 - Ensure above state persists even when MacOS decides to delete some
   of my spaces
 - Move focus to the next display when focusing 'east' or 'west' and
   already focused on the easter/westernmost window in the current
   display
 - Focus the fullscreened window in a given display
"""

import argparse
import json
import pickle
import subprocess
import sys
from collections import defaultdict
from contextlib import contextmanager
from pathlib import Path


@contextmanager
def singleton_lock():
    lock = Path("/tmp/yabaictl.lock")

    if lock.exists():
        sys.exit(1)

    lock.write_bytes(b"")
    try:
        yield
    finally:
        lock.unlink()


# these are used to determine display order
# you can find the uuids using `yabai -m query --displays`
setups = {
    "home": [
        "F1E65106-5CEE-4900-93D3-F80C5B62E417",  # center (Dell)
        "9C33325F-F961-4FFC-A2C3-9726BE7221DF",  # right (Asus)
        "37D8832A-2D66-02CA-B9F7-8F30A301B230",  # left (laptop)
    ],
    "laptop": [
        "37D8832A-2D66-02CA-B9F7-8F30A301B230",
    ],
}

ignored_monitors = [
    "DA40C9F5-43B9-4722-8F37-C7B215E46FB8",  # dummy
]

ignore_messages = [
    "acting space is already located on the given display.",
    "cannot focus an already focused space.",
]
# TODO: need to handle following errors:
"acting space is the last user-space on the source display and cannot be destroyed."
"acting space is the last user-space on the source display and cannot be moved."


def yabai_message(*msg):
    ret = subprocess.run(["yabai", "-m", *msg], capture_output=True)

    if ret.returncode:
        err_msg = ret.stderr.decode().strip()

        if err_msg not in ignore_messages:
            if "value 's' is not" in err_msg:
                print(msg)
            raise Exception(err_msg)
        else:
            print(f"While running {msg} we received error: {err_msg}\n")

    return ret.stdout.decode()


def yabai_query(domain):
    return json.loads(yabai_message("query", "--{}".format(domain)))


def find_all(objects, key, value):
    return (obj for obj in objects if obj[key] == value)


def find_one(objects, key, value):
    try:
        return next(find_all(objects, key, value))
    except StopIteration:
        return


class WindowManager:
    state = {"spaces": [], "displays": [], "windows": []}
    cache_path = Path("~/.cache/yabaictl").expanduser()

    NUM_SPACES = 10

    def __init__(self):
        self.found_setup = False
        self.refresh_state()

    @property
    def spaces(self):
        return self.state["spaces"]

    @property
    def displays(self):
        return self.state["displays"]

    @property
    def windows(self):
        return self.state["windows"]

    @property
    def num_displays(self):
        return len(self.displays)

    @property
    def num_spaces(self):
        return len(self.spaces)

    @property
    def num_windows(self):
        return len(self.windows)

    @property
    def unlabled_spaces(self):
        return list(find_all(self.spaces, "label", ""))

    @property
    def visible_spaces(self):
        return list(find_all(self.spaces, "visible", 1))

    @property
    def focused_space(self):
        return find_one(self.spaces, "focused", 1)

    @property
    def display_uuids(self):
        return [display["uuid"] for display in self.displays]

    @property
    def window_ids(self):
        return [window["id"] for window in self.windows]

    def find_monitor_setup(self):
        found_setup = False
        for setup in setups.values():
            if set(self.display_uuids) == set(setup):
                found_setup = True
                for ix, uuid in enumerate(setup):
                    self.find_display(uuid=uuid)["location"] = ix
        return found_setup

    def refresh_state(self):
        self.state["spaces"] = yabai_query("spaces")
        self.state["displays"] = yabai_query("displays")
        # remove ignored monitors from displays
        self.state["displays"] = [
            display
            for display in self.state["displays"]
            if display["uuid"] not in ignored_monitors
        ]

        self.state["windows"] = yabai_query("windows")

        if not self.find_monitor_setup():
            raise Exception("unidentified monitor setup")

    def label_space(self, space_index, label):
        yabai_message(
            "space",
            f"{space_index}",
            "--label",
            self._space_label(label),
        )

    def swap_context(self):
        """Swap spaces between the first and second spaces for each display."""
        for i in range(1, self.num_displays + 1):
            first = self.find_space(i)
            second = self.find_space(i + self.num_displays)
            self.label_space(first["index"], i + self.num_displays)
            self.label_space(second["index"], i)
        self.refocus_first_spaces()

    def save_state(self):
        with open(self.cache_path, "wb") as f:
            pickle.dump(self.state, f)

    def load_state(self):
        if not self.cache_path.exists():
            return defaultdict(dict)
        with open(self.cache_path, "rb") as f:
            return pickle.load(f)

    def find_display(self, display=None, index=None, uuid=None):
        """

        Parameters
        ----------
        display :
             Human identifiable display index (based on display order)
        index :
             System managed display index (based on returned value from yabai)
        uuid :
             System managed display UUID

        Returns
        -------

        """
        if display is not None:
            val = display
            key = "location"
        elif uuid is not None:
            val = uuid
            key = "uuid"
        elif index is not None:
            val = index
            key = "index"

        return find_one(self.displays, key, val)

    def find_space(self, space=None, index=None):
        """

        Parameters
        ----------
        space :
             Human identifiable space index. Can be just number or label (s<number>)
        index :
             System managed space index (based on returned value from yabai)

        Returns
        -------

        """
        if space is not None:
            # ensure we do the right thing whether a label or just number is provided
            val = self._space_label(space)
            key = "label"
        elif index is not None:
            val = index
            key = "index"

        return find_one(self.spaces, key, val)

    def _space_label(self, space):
        if "s" in str(space):
            if "s" == space:
                return "s1"
            return str(space)

        if not space:
            space = 1
        return f"s{space}"

    def display_for_space(self, space):
        return (space - 1) % self.num_displays

    def focus_space(self, space):
        yabai_message("space", "--focus", self._space_label(space))

    def focus_window(self, direction):
        """Move focus using `yabai -m window --focus` but allow moving across displays
        when using east or west."""
        try:
            yabai_message("window", "--focus", str(direction))
        except Exception as e:
            if f"could not locate a {direction}ward managed window." in str(e):
                """find next display in {direction}, then find active space in that
                display, then focus first(east)/last(west) window in that space."""
                yabai_message("display", "--focus", str(direction))

    def focus_fullscreen(self, display):
        """Focus the fullscreened space in the given display (starting at 1) if it exists"""
        display_index = self.find_display(display=int(display) - 1)["index"]

        for space in self.spaces:
            if space["display"] == display_index and space["is-native-fullscreen"]:
                yabai_message("space", "--focus", f"{space['index']}")

    def move_space_to_display(self, space, display):
        display_index = self.find_display(display=display)["index"]

        yabai_message(
            "space",
            self._space_label(space),
            "--display",
            f"{display_index}",
        )

    def move_window_to_space(self, window, space):
        yabai_message("window", str(window), "--space", self._space_label(space))

    def remove_unnecessary_spaces(self):
        if self.num_spaces > self.NUM_SPACES:
            for unlabled_space in self.unlabled_spaces:
                yabai_message("space", f"{unlabled_space['index']}", "--destroy")

    def ensure_spaces(self):
        if self.num_spaces < self.NUM_SPACES:
            for i in range(self.num_spaces, self.NUM_SPACES):
                yabai_message("space", "--create")

    def ensure_labels(self):
        wanted_labels = set(self._space_label(i) for i in range(1, self.NUM_SPACES + 1))
        existing_labels = set(space["label"] for space in self.spaces)

        for ix, missing_label in enumerate(sorted(wanted_labels - existing_labels)):
            self.label_space(self.unlabled_spaces[ix]["index"], missing_label)

    def refocus_first_spaces(self):
        for i in range(1, self.num_displays + 1):
            self.focus_space(i)

    def reorganize_spaces(self):
        old_state = self.load_state()

        for space_index in range(1, self.NUM_SPACES + 1):
            self.move_space_to_display(
                space_index,
                self.display_for_space(space_index),
            )

        for space in old_state["spaces"]:
            if space == "s":
                space = "s1"
            for window in space["windows"]:
                if window in self.window_ids:
                    self.move_window_to_space(window, space["label"])

        # after re-shuffling, focus the "default" spaces
        self.refocus_first_spaces()

    def update_spaces(self):
        self.ensure_spaces()
        self.refresh_state()

        self.ensure_labels()
        self.refresh_state()

        self.reorganize_spaces()

        self.remove_unnecessary_spaces()
        self.refresh_state()


def add_subcommand(sub, func, subcommand_name, subcommand_args=[]):
    parser = sub.add_parser(subcommand_name)
    parser.set_defaults(func=func)
    for arg in subcommand_args:
        parser.add_argument(arg)


def parse_args(wm):
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers()

    add_subcommand(sub, wm.update_spaces, "update-spaces")
    add_subcommand(sub, wm.swap_context, "swap-context")
    add_subcommand(sub, wm.focus_space, "focus-space", ["space"])
    add_subcommand(sub, wm.focus_fullscreen, "focus-fullscreen", ["display"])
    add_subcommand(sub, wm.focus_window, "focus-window", ["direction"])

    args = vars(parser.parse_args())
    return args.pop("func"), args


if __name__ == "__main__":
    with singleton_lock():
        wm = WindowManager()
        func, args = parse_args(wm)
        func(**args)

        wm.save_state()
