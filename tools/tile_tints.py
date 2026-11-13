#!/usr/bin/env python3
"""Tile colours for GameTokens: the grey lightness ramps tinted in OKLCH with the design system's
Signal hues (blue/green/amber/red) at the SAME lightness, plus the text contrast of each step.
Run: python3 tools/tile_tints.py — paste the printed ramps into GameTokens.swift."""
import math
def s2l(c): c/=255; return c/12.92 if c<=0.04045 else ((c+0.055)/1.055)**2.4
def l2s(c): c=max(0,min(1,c)); v=12.92*c if c<=0.0031308 else 1.055*c**(1/2.4)-0.055; return round(v*255)
def hex2rgb(h): return [(h>>16)&255,(h>>8)&255,h&255]
def to_oklab(rgb):
    r,g,b=[s2l(x) for x in rgb]
    l=0.4122214708*r+0.5363325363*g+0.0514459929*b
    m=0.2119034982*r+0.6806995451*g+0.1073969566*b
    s=0.0883024619*r+0.2817188376*g+0.6299787005*b
    l,m,s=[x**(1/3) for x in (l,m,s)]
    return (0.2104542553*l+0.7936177850*m-0.0040720468*s, 1.9779984951*l-2.4285922050*m+0.4505937099*s, 0.0259040371*l+0.7827717662*m-0.8086757660*s)
def from_oklab(L,a,b):
    l=(L+0.3963377774*a+0.2158037573*b)**3
    m=(L-0.1055613458*a-0.0638541728*b)**3
    s=(L-0.0894841775*a-1.2914855480*b)**3
    r=4.0767416621*l-3.3077115913*m+0.2309699292*s
    g=-1.2684380046*l+2.6097574011*m-0.3413193965*s
    bb=-0.0041960863*l-0.7034186147*m+1.7076147010*s
    return r,g,bb
def lum(rgb):
    r,g,b=[s2l(x) for x in rgb]; return 0.2126*r+0.7152*g+0.0722*b
def contrast(a,b):
    la,lb=sorted([lum(a),lum(b)],reverse=True); return (la+0.05)/(lb+0.05)
def hue_of(h):
    L,a,b=to_oklab(hex2rgb(h)); return math.atan2(b,a)
H={'blue':hue_of(0x007AFF),'green':hue_of(0x28BD4E),'amber':hue_of(0xE8930C),'red':hue_of(0xFF3B30)}
# 2 is neutral; 4 is a faint warm (amber) step so it parts clearly from 2.
# Per step (2, 4 … 1024, 2048): OKLab lightness, hue family, chroma. Coloured steps stay in the
# mid-light band in BOTH themes, so amber reads as sand and red as coral (never brown/maroon).
LIGHT = dict(L=[1.00, 0.925, 0.915, 0.865, 0.845, 0.79, 0.80, 0.74, 0.70, 0.62, 0.12],
             C=[0, 0.030, 0.040, 0.060, 0.055, 0.075, 0.080, 0.100, 0.110, 0.130, 0])
DARK = dict(L=[0.34, 0.41, 0.42, 0.48, 0.50, 0.56, 0.68, 0.74, 0.74, 0.84, 1.00],
            C=[0, 0.022, 0.040, 0.055, 0.050, 0.065, 0.075, 0.085, 0.090, 0.070, 0])
PLAN = [None, 'amber', 'blue', 'blue', 'green', 'green', 'amber', 'amber', 'red', 'red', None]
INK = [6, 6, 7]
WHITE = [255, 255, 255]

def make(L, C, hue):
    if hue is None:
        r = g = b = from_oklab(L, 0, 0)[0]
        return [l2s(r)] * 3
    c = C
    while c > 0:
        rgb = from_oklab(L, c * math.cos(H[hue]), c * math.sin(H[hue]))
        if all(-0.001 <= x <= 1.001 for x in rgb):
            break
        c -= 0.002
    return [l2s(x) for x in rgb]

for name, spec in (('light', LIGHT), ('dark', DARK)):
    fills, inks = [], []
    for i in range(11):
        rgb = make(spec['L'][i], spec['C'][i], PLAN[i])
        white = contrast(rgb, WHITE) > contrast(rgb, INK)
        fills.append('0x%02X%02X%02X' % tuple(rgb))
        inks.append(white)
        print('  %5d %s %s %.2f' % (2 ** (i + 1), fills[-1], 'white' if white else 'ink  ',
                                    max(contrast(rgb, WHITE), contrast(rgb, INK))))
    print(name, ', '.join(fills))
    print(name, 'whiteText', [i for i, w in enumerate(inks) if w])
