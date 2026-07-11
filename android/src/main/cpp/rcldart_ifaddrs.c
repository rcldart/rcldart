// rcldart_ifaddrs.c — Android getifaddrs()/freeifaddrs() shim.
//
// Why: CycloneDDS/FastDDS enumerate network interfaces with getifaddrs() to
// choose where to send discovery traffic. Inside an Android app sandbox
// bionic's getifaddrs() does not surface a usable AF_INET interface, so DDS
// finds zero peers and rcl "works" but never talks to anything.
//
// This shim parses the output of `ip addr` (falling back to `ifconfig`) and
// builds a struct ifaddrs list, preferring the Wi-Fi (wlan*) interface. Load
// it before rcl with RTLD_GLOBAL so the DDS layer binds to our getifaddrs.
//
// Adapted from botforge-robotics/ros2_android (MIT) patch_getifaddrs.c.
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <net/if.h>

#ifdef __ANDROID__
#include <android/log.h>
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, "rcldart_ifaddrs", __VA_ARGS__)
#else
#define LOGI(...) fprintf(stderr, __VA_ARGS__)
#endif

// Parse `ip -o -4 addr show` (one line per address) then `ifconfig` as a
// fallback, into a struct ifaddrs list. wlan* interfaces are put first.
static int parse_interfaces(struct ifaddrs **ifap) {
  struct ifaddrs *wlan_head = NULL, *wlan_prev = NULL;
  struct ifaddrs *other_head = NULL, *other_prev = NULL;
  char name[64], addr_s[64];

  // Try `ip` first (present on modern Android).
  FILE *fp = popen("ip -o -4 addr show 2>/dev/null", "r");
  int got = 0;
  if (fp) {
    char line[512];
    while (fgets(line, sizeof(line), fp)) {
      // e.g. "23: wlan0    inet 192.168.1.42/24 brd ..."
      if (sscanf(line, "%*d: %63s %*s %63[^/]", name, addr_s) == 2 ||
          sscanf(line, "%*d: %63s inet %63[^/]", name, addr_s) == 2) {
        struct ifaddrs *ifa = calloc(1, sizeof(struct ifaddrs));
        ifa->ifa_name = strdup(name);
        ifa->ifa_flags = IFF_UP | IFF_RUNNING | IFF_BROADCAST | IFF_MULTICAST;
        struct sockaddr_in *sin = calloc(1, sizeof(struct sockaddr_in));
        sin->sin_family = AF_INET;
        inet_pton(AF_INET, addr_s, &sin->sin_addr);
        ifa->ifa_addr = (struct sockaddr *)sin;
        int is_wlan = (strncmp(name, "wlan", 4) == 0);
        if (is_wlan) {
          if (wlan_prev) wlan_prev->ifa_next = ifa; else wlan_head = ifa;
          wlan_prev = ifa;
        } else {
          if (other_prev) other_prev->ifa_next = ifa; else other_head = ifa;
          other_prev = ifa;
        }
        got++;
      }
    }
    pclose(fp);
  }

  // Fallback: parse `ifconfig` if `ip` produced nothing.
  if (!got) {
    fp = popen("ifconfig 2>/dev/null", "r");
    if (fp) {
      char line[256];
      struct ifaddrs *cur = NULL;
      int is_wlan = 0;
      while (fgets(line, sizeof(line), fp)) {
        if (sscanf(line, "%63[^: ]", name) == 1 && strstr(line, "flags")) {
          struct ifaddrs *ifa = calloc(1, sizeof(struct ifaddrs));
          ifa->ifa_name = strdup(name);
          ifa->ifa_flags = IFF_UP | IFF_RUNNING | IFF_BROADCAST | IFF_MULTICAST;
          is_wlan = (strncmp(name, "wlan", 4) == 0);
          cur = ifa;
          if (is_wlan) {
            if (wlan_prev) wlan_prev->ifa_next = ifa; else wlan_head = ifa;
            wlan_prev = ifa;
          } else {
            if (other_prev) other_prev->ifa_next = ifa; else other_head = ifa;
            other_prev = ifa;
          }
        } else if (cur && strstr(line, "inet ")) {
          if (sscanf(line, " inet %63s", addr_s) == 1) {
            struct sockaddr_in *sin = calloc(1, sizeof(struct sockaddr_in));
            sin->sin_family = AF_INET;
            inet_pton(AF_INET, addr_s, &sin->sin_addr);
            cur->ifa_addr = (struct sockaddr *)sin;
          }
        }
      }
      pclose(fp);
    }
  }

  if (wlan_prev) wlan_prev->ifa_next = other_head; // wlan first, then the rest
  *ifap = wlan_head ? wlan_head : other_head;
  LOGI("getifaddrs shim: wlan=%p other=%p", (void *)wlan_head, (void *)other_head);
  return 0;
}

int getifaddrs(struct ifaddrs **ifap) { return parse_interfaces(ifap); }

void freeifaddrs(struct ifaddrs *ifa) {
  while (ifa) {
    struct ifaddrs *next = ifa->ifa_next;
    free(ifa->ifa_addr);
    free(ifa->ifa_name);
    free(ifa);
    ifa = next;
  }
}
