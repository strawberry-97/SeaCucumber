#!/usr/bin/env python3
"""把 VpnManager.swift / SharedConstants.swift 注册进 iOS / macOS 的 Xcode 工程。

用法：
    python3 scripts/add_swift_to_xcode.py
"""
import re
import sys

FILES = ["VpnManager.swift", "SharedConstants.swift"]


def add_files(pbxproj_path, id_prefix):
    with open(pbxproj_path, "r", encoding="utf-8") as f:
        content = f.read()

    new_buildfiles = ""
    new_filerefs = ""
    new_children = ""
    new_sources = ""
    ids = {}

    for i, name in enumerate(FILES):
        # 保证 24 位十六进制且唯一
        fileref = f"{id_prefix}{i:02X}00000000"[:24]
        buildfile = f"{id_prefix}{i:02X}FFFFFFFF"[:24]
        ids[name] = (fileref, buildfile)
        new_buildfiles += (
            f"\t\t{buildfile} /* {name} in Sources */ = "
            f"{{isa = PBXBuildFile; fileRef = {fileref} /* {name} */; }};\n"
        )
        new_filerefs += (
            f"\t\t{fileref} /* {name} */ = "
            f"{{isa = PBXFileReference; fileEncoding = 4; "
            f"lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n"
        )
        new_children += f"\t\t\t\t{fileref} /* {name} */,\n"
        new_sources += f"\t\t\t\t{buildfile} /* {name} in Sources */,\n"

    # 1. PBXBuildFile section
    content = re.sub(
        r"(/\* End PBXBuildFile section \*/)",
        new_buildfiles + r"\1",
        content,
        count=1,
    )
    # 2. PBXFileReference section
    content = re.sub(
        r"(/\* End PBXFileReference section \*/)",
        new_filerefs + r"\1",
        content,
        count=1,
    )
    # 3. Runner group children（在 AppDelegate.swift 之后插入）
    anchor = None
    for name in ["AppDelegate.swift", "MainFlutterWindow.swift"]:
        m = re.search(rf"(\t\t\t\t[0-9A-F]{{24}} /\* {name} \*/,\n)", content)
        if m:
            anchor = m.group(1)
            break
    if anchor is None:
        print(f"未找到 Runner group 锚点: {pbxproj_path}")
        sys.exit(1)
    content = content.replace(anchor, anchor + new_children, 1)
    # 4. Runner Sources build phase（在 AppDelegate.swift in Sources 之后插入）
    anchor2 = None
    for name in ["AppDelegate.swift", "MainFlutterWindow.swift"]:
        m = re.search(rf"(\t\t\t\t[0-9A-F]{{24}} /\* {name} in Sources \*/,\n)", content)
        if m:
            anchor2 = m.group(1)
            break
    if anchor2 is None:
        print(f"未找到 Sources phase 锚点: {pbxproj_path}")
        sys.exit(1)
    content = content.replace(anchor2, anchor2 + new_sources, 1)

    with open(pbxproj_path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"已更新 {pbxproj_path}")


if __name__ == "__main__":
    add_files(
        "ios/Runner.xcodeproj/project.pbxproj",
        "AAAA0000000000000000",
    )
    add_files(
        "macos/Runner.xcodeproj/project.pbxproj",
        "BBBB0000000000000000",
    )
