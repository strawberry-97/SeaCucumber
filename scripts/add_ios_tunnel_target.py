#!/usr/bin/env python3
"""在 iOS Runner.xcodeproj 中创建 Network Extension 目标 `tunnel`。

用法（在项目根目录）：
    python3 scripts/add_ios_tunnel_target.py

目标 bundle id：com.scvpn.vpnApp.tunnel
App Group：group.com.scvpn.vpnApp（需在开发者后台注册并配置签名）
"""
import re
import sys

PBXPROJ = "ios/Runner.xcodeproj/project.pbxproj"

# 24 位十六进制 ID（前缀 B 系列，避免与现有冲突）
IDS = {
    # PBXBuildFile
    "bf_packet": "B10000000000000000000001",
    "bf_platform": "B10000000000000000000002",
    "bf_shared": "B10000000000000000000003",
    "bf_libbox": "B10000000000000000000004",
    "bf_appex_embed": "B10000000000000000000005",
    # PBXFileReference
    "fr_packet": "B20000000000000000000001",
    "fr_platform": "B20000000000000000000002",
    "fr_shared": "B20000000000000000000003",
    "fr_info": "B20000000000000000000004",
    "fr_entitlements": "B20000000000000000000005",
    "fr_libbox": "B20000000000000000000006",
    "fr_appex": "B20000000000000000000007",
    # PBXNativeTarget
    "target": "B40000000000000000000001",
    # PBXBuildPhase
    "bp_sources": "B50000000000000000000001",
    "bp_frameworks": "B50000000000000000000002",
    "bp_resources": "B50000000000000000000003",
    "bp_embed_ext": "B50000000000000000000004",
    # Container proxy / dependency
    "proxy": "B60000000000000000000001",
    "dep": "B60000000000000000000002",
    # XCConfigurationList
    "cfglist": "B70000000000000000000001",
    # XCBuildConfiguration
    "cfg_debug": "B80000000000000000000001",
    "cfg_release": "B80000000000000000000002",
    "cfg_profile": "B80000000000000000000003",
    # PBXGroup
    "grp_tunnel": "B90000000000000000000001",
    "grp_frameworks": "B90000000000000000000002",
}


def read():
    with open(PBXPROJ, "r", encoding="utf-8") as f:
        return f.read()


def write(s):
    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(s)


def insert_after(s, marker, text):
    """在包含 marker 的整行之后插入 text（首次匹配）"""
    idx = s.find(marker)
    if idx == -1:
        print(f"[错误] 找不到标记: {marker}")
        sys.exit(1)
    line_end = s.find("\n", idx)
    return s[: line_end + 1] + text + s[line_end + 1 :]


def main():
    s = read()
    i = IDS

    # ---- PBXBuildFile ----
    s = insert_after(s, "/* End PBXBuildFile section */", f"""\t\t{i["bf_packet"]} /* PacketTunnelProvider.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {i["fr_packet"]} /* PacketTunnelProvider.swift */; }};
\t\t{i["bf_platform"]} /* PlatformInterface.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {i["fr_platform"]} /* PlatformInterface.swift */; }};
\t\t{i["bf_shared"]} /* SharedConstants.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {i["fr_shared"]} /* SharedConstants.swift */; }};
\t\t{i["bf_libbox"]} /* Libbox.xcframework in Frameworks */ = {{isa = PBXBuildFile; fileRef = {i["fr_libbox"]} /* Libbox.xcframework */; }};
\t\t{i["bf_appex_embed"]} /* tunnel.appex in Embed App Extensions */ = {{isa = PBXBuildFile; fileRef = {i["fr_appex"]} /* tunnel.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};
""")

    # ---- PBXContainerItemProxy ----
    s = insert_after(s, "/* End PBXContainerItemProxy section */", f"""\t\t{i["proxy"]} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = 97C146E61CF9000F007C117D /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {i["target"]};
\t\t\tremoteInfo = tunnel;
\t\t}};
""")

    # ---- PBXCopyFilesBuildPhase ----
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

    # ---- PBXFileReference ----
    s = insert_after(s, "/* End PBXFileReference section */", f"""\t\t{i["fr_packet"]} /* PacketTunnelProvider.swift */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = PacketTunnelProvider.swift; sourceTree = "<group>"; }};
\t\t{i["fr_platform"]} /* PlatformInterface.swift */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = PlatformInterface.swift; sourceTree = "<group>"; }};
\t\t{i["fr_shared"]} /* SharedConstants.swift */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = SharedConstants.swift; sourceTree = "<group>"; }};
\t\t{i["fr_info"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};
\t\t{i["fr_entitlements"]} /* tunnel.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = tunnel.entitlements; sourceTree = "<group>"; }};
\t\t{i["fr_libbox"]} /* Libbox.xcframework */ = {{isa = PBXFileReference; lastKnownFileType = wrapper.xcframework; path = Libbox.xcframework; sourceTree = "<group>"; }};
\t\t{i["fr_appex"]} /* tunnel.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = tunnel.appex; sourceTree = BUILT_PRODUCTS_DIR; }};
""")

    # ---- PBXFrameworksBuildPhase ----
    s = insert_after(s, "/* End PBXFrameworksBuildPhase section */", f"""\t\t{i["bp_frameworks"]} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{i["bf_libbox"]} /* Libbox.xcframework in Frameworks */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
""")

    # ---- PBXGroup：主 group 增加 Tunnel 与 Frameworks ----
    s = s.replace(
        "\t\t\t\t331C8082294A63A400263BE5 /* RunnerTests */,\n",
        "\t\t\t\t331C8082294A63A400263BE5 /* RunnerTests */,\n"
        f"\t\t\t\t{i['grp_tunnel']} /* Tunnel */,\n"
        f"\t\t\t\t{i['grp_frameworks']} /* Frameworks */,\n",
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
\t\t\tpath = Tunnel;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{i["grp_frameworks"]} /* Frameworks */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{i["fr_libbox"]} /* Libbox.xcframework */,
\t\t\t);
\t\t\tpath = Frameworks;
\t\t\tsourceTree = "<group>";
\t\t}};
""")

    # ---- PBXNativeTarget：新增 tunnel，并给 Runner 加依赖 + Embed App Extensions ----
    s = s.replace(
        "\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n\t\t\t);",
        "\t\t\t\t3B06AD1E1E4923F5004D2608 /* Thin Binary */,\n"
        f"\t\t\t\t{i['bp_embed_ext']} /* Embed App Extensions */,\n\t\t\t);",
        1,
    )
    s = s.replace(
        "\t\t\tdependencies = (\n\t\t\t);\n\t\t\tname = Runner;",
        "\t\t\tdependencies = (\n"
        f"\t\t\t\t{i['dep']} /* PBXTargetDependency */,\n"
        "\t\t\t);\n\t\t\tname = Runner;",
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

    # ---- PBXProject：targets 列表 + TargetAttributes ----
    s = s.replace(
        "\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,\n"
        "\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n\t\t\t);",
        "\t\t\t\t97C146ED1CF9000F007C117D /* Runner */,\n"
        "\t\t\t\t331C8080294A63A400263BE5 /* RunnerTests */,\n"
        f"\t\t\t\t{i['target']} /* tunnel */,\n\t\t\t);",
        1,
    )
    s = s.replace(
        "\t\t\t\t\t97C146ED1CF9000F007C117D = {\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n"
        "\t\t\t\t\t\tLastSwiftMigration = 1100;\n"
        "\t\t\t\t\t};",
        "\t\t\t\t\t97C146ED1CF9000F007C117D = {\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 7.3.1;\n"
        "\t\t\t\t\t\tLastSwiftMigration = 1100;\n"
        "\t\t\t\t\t};\n"
        f"\t\t\t\t\t{i['target']} = {{\n"
        "\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n"
        "\t\t\t\t\t};",
        1,
    )

    # ---- PBXResourcesBuildPhase ----
    s = insert_after(s, "/* End PBXResourcesBuildPhase section */", f"""\t\t{i["bp_resources"]} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
""")

    # ---- PBXSourcesBuildPhase ----
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

    # ---- PBXTargetDependency ----
    s = insert_after(s, "/* End PBXTargetDependency section */", f"""\t\t{i["dep"]} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {i["target"]} /* tunnel */;
\t\t\ttargetProxy = {i["proxy"]} /* PBXContainerItemProxy */;
\t\t}};
""")

    # ---- XCBuildConfiguration（tunnel 三套配置）----
    s = insert_after(s, "/* End XCBuildConfiguration section */", f"""\t\t{i["cfg_debug"]} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = Tunnel/tunnel.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = Tunnel/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tOTHER_LDFLAGS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"-framework",
\t\t\t\t\tNetworkExtension,
\t\t\t\t\t"-lresolv",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.scvpn.vpnApp.tunnel;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{i["cfg_release"]} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = Tunnel/tunnel.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = Tunnel/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tOTHER_LDFLAGS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"-framework",
\t\t\t\t\tNetworkExtension,
\t\t\t\t\t"-lresolv",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.scvpn.vpnApp.tunnel;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{i["cfg_profile"]} /* Profile */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_ENTITLEMENTS = Tunnel/tunnel.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_FILE = Tunnel/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@executable_path/../../Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tOTHER_LDFLAGS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"-framework",
\t\t\t\t\tNetworkExtension,
\t\t\t\t\t"-lresolv",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.scvpn.vpnApp.tunnel;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSKIP_INSTALL = YES;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Profile;
\t\t}};
""")

    # ---- XCConfigurationList ----
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
