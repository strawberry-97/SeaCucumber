#!/usr/bin/env python3
"""在 macOS Runner.xcodeproj 中创建 Network Extension 目标 `tunnel`。

用法（在项目根目录）：
    python3 scripts/add_macos_tunnel_target.py

前置：先把带 macos slice 的 Libbox.xcframework 放到 macos/Frameworks/（见
scripts/build_libbox_macos.sh）。
"""
import sys

PBXPROJ = "macos/Runner.xcodeproj/project.pbxproj"

IDS = {
    "bf_packet": "C10000000000000000000001",
    "bf_platform": "C10000000000000000000002",
    "bf_shared": "C10000000000000000000003",
    "bf_libbox": "C10000000000000000000004",
    "bf_appex_embed": "C10000000000000000000005",
    "fr_packet": "C20000000000000000000001",
    "fr_platform": "C20000000000000000000002",
    "fr_shared": "C20000000000000000000003",
    "fr_info": "C20000000000000000000004",
    "fr_entitlements": "C20000000000000000000005",
    "fr_libbox": "C20000000000000000000006",
    "fr_appex": "C20000000000000000000007",
    "target": "C40000000000000000000001",
    "bp_sources": "C50000000000000000000001",
    "bp_frameworks": "C50000000000000000000002",
    "bp_resources": "C50000000000000000000003",
    "bp_embed_ext": "C50000000000000000000004",
    "proxy": "C60000000000000000000001",
    "dep": "C60000000000000000000002",
    "cfglist": "C70000000000000000000001",
    "cfg_debug": "C80000000000000000000001",
    "cfg_release": "C80000000000000000000002",
    "cfg_profile": "C80000000000000000000003",
    "grp_tunnel": "C90000000000000000000001",
}


def read():
    with open(PBXPROJ, "r", encoding="utf-8") as f:
        return f.read()


def write(s):
    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(s)


def insert_after(s, marker, text):
    idx = s.find(marker)
    if idx == -1:
        print(f"[错误] 找不到标记: {marker}")
        sys.exit(1)
    line_end = s.find("\n", idx)
    return s[: line_end + 1] + text + s[line_end + 1 :]


def main():
    s = read()
    i = IDS

    # PBXBuildFile
    s = insert_after(s, "/* End PBXBuildFile section */", f"""\t\t{i["bf_packet"]} /* PacketTunnelProvider.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {i["fr_packet"]} /* PacketTunnelProvider.swift */; }};
\t\t{i["bf_platform"]} /* PlatformInterface.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {i["fr_platform"]} /* PlatformInterface.swift */; }};
\t\t{i["bf_shared"]} /* SharedConstants.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {i["fr_shared"]} /* SharedConstants.swift */; }};
\t\t{i["bf_libbox"]} /* Libbox.xcframework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {i["fr_libbox"]} /* Libbox.xcframework */; }};
\t\t{i["bf_appex_embed"]} /* tunnel.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {i["fr_appex"]} /* tunnel.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
""")

    # PBXContainerItemProxy
    s = insert_after(s, "/* End PBXContainerItemProxy section */", f"""\t\t{i["proxy"]} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = 33CC10E52044A3C60003C045 /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {i["target"]};
\t\t\tremoteInfo = tunnel;
\t\t}};
""")

    # PBXCopyFilesBuildPhase
    s = insert_after(s, "/* End PBXCopyFilesBuildPhase section */", f"""\t\t{i["bp_embed_ext"]} /* Embed App Extensions */ = {{
\t\t\tisa = PBXCopyFilesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tdstPath = "";
\t\t\tdstSubfolderSpec = 13;
\t\t\tfiles = (
\t\t\t\t{i["bf_appex_embed"]} /* tunnel.appex in Embed App Extensions */,
\t\t\t);
\t\t\tname = "Embed App Extensions";
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
""")

    # PBXFileReference
    s = insert_after(s, "/* End PBXFileReference section */", f"""\t\t{i["fr_packet"]} /* PacketTunnelProvider.swift */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = PacketTunnelProvider.swift; sourceTree = "<group>"; }};
\t\t{i["fr_platform"]} /* PlatformInterface.swift */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = PlatformInterface.swift; sourceTree = "<group>"; }};
\t\t{i["fr_shared"]} /* SharedConstants.swift */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = SharedConstants.swift; sourceTree = "<group>"; }};
\t\t{i["fr_info"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
\t\t{i["fr_entitlements"]} /* tunnel.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = tunnel.entitlements; sourceTree = "<group>"; }};
\t\t{i["fr_libbox"]} /* Libbox.xcframework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = "Frameworks/Libbox.xcframework"; sourceTree = "<group>"; }};
\t\t{i["fr_appex"]} /* tunnel.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = tunnel.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
""")

    # PBXFrameworksBuildPhase
    s = insert_after(s, "/* End PBXFrameworksBuildPhase section */", f"""\t\t{i["bp_frameworks"]} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{i["bf_libbox"]} /* Libbox.xcframework in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
""")

    # 主 group 增加 Tunnel
    s = s.replace(
        "\t\t\t\tD73912EC22F37F3D000D13A0 /* Frameworks */,\n",
        "\t\t\t\tD73912EC22F37F3D000D13A0 /* Frameworks */,\n"
        f"\t\t\t\t{i['grp_tunnel']} /* Tunnel */,\n",
        1,
    )
    # Frameworks group 增加 Libbox
    s = s.replace(
        "\t\tD73912EC22F37F3D000D13A0 /* Frameworks */ = {\n"
        "\t\t\tisa = PBXGroup;\n"
        "\t\t\tchildren = (\n"
        "\t\t\t);",
        "\t\tD73912EC22F37F3D000D13A0 /* Frameworks */ = {\n"
        "\t\t\tisa = PBXGroup;\n"
        "\t\t\tchildren = (\n"
        f"\t\t\t\t{i['fr_libbox']} /* Libbox.xcframework */,\n"
        "\t\t\t);",
        1,
    )
    s = insert_after(s, "/* End PBXGroup section */", f"""\t\t{i["grp_tunnel"]} /* Tunnel */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{i["fr_packet"]} /* PacketTunnelProvider.swift */,
\t\t\t\t{i["fr_platform"]} /* PlatformInterface.swift */,
\t\t\t\t{i["fr_shared"]} /* SharedConstants.swift */,
\t\t\t\t{i["fr_info"]} /* Info.plist */,
\t\t\t\t{i["fr_entitlements"]} /* tunnel.entitlements */,
\t\t\t);
\t\t\tpath = TunnelExtension;
\t\t\tsourceTree = "<group>";
\t\t}};
""")

    # Runner 增加 Embed App Extensions 与依赖
    s = s.replace(
        "\t\t\t\t3399D490228B24CF009A79C7 /* ShellScript */,\n\t\t\t);",
        "\t\t\t\t3399D490228B24CF009A79C7 /* ShellScript */,\n"
        f"\t\t\t\t{i['bp_embed_ext']} /* Embed App Extensions */,\n\t\t\t);",
        1,
    )
    s = s.replace(
        "\t\t\tdependencies = (\n"
        "\t\t\t\t33CC11202044C79F0003C045 /* PBXTargetDependency */,\n"
        "\t\t\t);",
        "\t\t\tdependencies = (\n"
        "\t\t\t\t33CC11202044C79F0003C045 /* PBXTargetDependency */,\n"
        f"\t\t\t\t{i['dep']} /* PBXTargetDependency */,\n"
        "\t\t\t);",
        1,
    )
    s = insert_after(s, "/* End PBXNativeTarget section */", f"""\t\t{i["target"]} /* tunnel */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {i["cfglist"]} /* Build configuration list for PBXNativeTarget "tunnel" */;
\t\t\tbuildPhases = (
\t\t\t\t{i["bp_sources"]} /* Sources */,
\t\t\t\t{i["bp_frameworks"]} /* Frameworks */,
\t\t\t\t{i["bp_resources"]} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = tunnel;
\t\t\tproductName = tunnel;
\t\t\tproductReference = {i["fr_appex"]} /* tunnel.appex */;
\t\t\tproductType = "com.apple.product-type.app-extension";
\t\t}};
""")

    # PBXProject：targets 列表 + TargetAttributes
    s = s.replace(
        "\t\t\t\t33CC10EC2044A3C60003C045 /* Runner */,\n"
        "\t\t\t\t331C80D4294CF70F00263BE5 /* RunnerTests */,\n"
        "\t\t\t\t33CC111A2044C6BA0003C045 /* Flutter Assemble */,\n\t\t\t);",
        "\t\t\t\t33CC10EC2044A3C60003C045 /* Runner */,\n"
        "\t\t\t\t331C80D4294CF70F00263BE5 /* RunnerTests */,\n"
        "\t\t\t\t33CC111A2044C6BA0003C045 /* Flutter Assemble */,\n"
        f"\t\t\t\t{i['target']} /* tunnel */,\n\t\t\t);",
        1,
    )
    s = s.replace(
        "\t\t\t\t\t33CC10EC2044A3C60003C045 = {\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 9.2;\n"
        "\t\t\t\t\t\tLastSwiftMigration = 1100;",
        "\t\t\t\t\t33CC10EC2044A3C60003C045 = {\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 9.2;\n"
        "\t\t\t\t\t\tLastSwiftMigration = 1100;",
        1,
    )
    # 在 TargetAttributes 中为 tunnel 增加条目
    s = s.replace(
        "\t\t\t\t\t331C80D4294CF70F00263BE5 = {\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 14.0;\n"
        "\t\t\t\t\t\tTestTargetID = 33CC10EC2044A3C60003C045;\n"
        "\t\t\t\t\t};",
        "\t\t\t\t\t331C80D4294CF70F00263BE5 = {\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 14.0;\n"
        "\t\t\t\t\t\tTestTargetID = 33CC10EC2044A3C60003C045;\n"
        "\t\t\t\t\t};\n"
        f"\t\t\t\t\t{i['target']} = {{\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n"
        "\t\t\t\t\t};",
        1,
    )

    # PBXResourcesBuildPhase
    s = insert_after(s, "/* End PBXResourcesBuildPhase section */", f"""\t\t{i["bp_resources"]} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
""")

    # PBXSourcesBuildPhase
    s = insert_after(s, "/* End PBXSourcesBuildPhase section */", f"""\t\t{i["bp_sources"]} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{i["bf_packet"]} /* PacketTunnelProvider.swift in Sources */,
\t\t\t\t{i["bf_platform"]} /* PlatformInterface.swift in Sources */,
\t\t\t\t{i["bf_shared"]} /* SharedConstants.swift in Sources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
""")

    # PBXTargetDependency
    s = insert_after(s, "/* End PBXTargetDependency section */", f"""\t\t{i["dep"]} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {i["target"]} /* tunnel */;
\t\t\ttargetProxy = {i["proxy"]} /* PBXContainerItemProxy */;
\t\t}};
""")

    # XCBuildConfiguration（tunnel 三套）
    def build_settings(name):
        return f"""\t\t{i[f"cfg_{name}"]} /* {name.capitalize()} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = TunnelExtension/tunnel.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOMBINE_HIDPI_IMAGES = YES;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = TunnelExtension/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t\t"@executable_path/../../../../Frameworks",
\t\t\t\t);
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 12.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tOTHER_LDFLAGS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"-framework",
\t\t\t\t\tAppKit,
\t\t\t\t\t"-framework",
\t\t\t\t\tNetworkExtension,
\t\t\t\t\t"-framework",
\t\t\t\t\tSystemConfiguration,
\t\t\t\t\t"-framework",
\t\t\t\t\tCoreFoundation,
\t\t\t\t\t"-framework",
\t\t\t\t\tSecurity,
\t\t\t\t\t"-lresolv",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.scvpn.vpnApp.tunnel;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t}};
\t\t\tname = {name.capitalize()};
\t\t}};
"""

    s = insert_after(s, "/* End XCBuildConfiguration section */",
                     build_settings("debug") + build_settings("release") + build_settings("profile"))

    # XCConfigurationList
    s = insert_after(s, "/* End XCConfigurationList section */", f"""\t\t{i["cfglist"]} /* Build configuration list for PBXNativeTarget "tunnel" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{i["cfg_debug"]} /* Debug */,
\t\t\t\t{i["cfg_release"]} /* Release */,
\t\t\t\t{i["cfg_profile"]} /* Profile */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
""")

    write(s)
    print(f"已更新 {PBXPROJ}")


if __name__ == "__main__":
    main()
