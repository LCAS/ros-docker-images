#!/bin/bash
export VGL_FPS=30
export VGL_DISPLAY=egl
/opt/TurboVNC/bin/vncserver -vgl -depth 24  -securitytypes TLSNone,X509None,None -wm xfce4-session > /tmp/vnc.log 2>&1
/usr/local/novnc/noVNC-1.4.0/utils/novnc_proxy --vnc localhost:5901 --listen 5801 > /tmp/novnc.log 2>&1 &
