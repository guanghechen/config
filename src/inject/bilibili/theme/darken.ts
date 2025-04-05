export const darkTheme: string = `
  #app {
    background-color: var(--bg1);
  }
  :root {
    /* Grayscale - Inverted from light theme */
    --Ga0: #18191c;
    --Ga0_s: #18191c;
    --Ga0_t: #18191c;
    --Ga1: #2f3238;
    --Ga1_s: #2f3238;
    --Ga1_t: #2f3238;
    --Ga1_e: #2f3238;
    --Ga2: #484c53;
    --Ga2_t: #484c53;
    --Ga3: #61666d;
    --Ga3_t: #61666d;
    --Ga4: #797f87;
    --Ga4_t: #797f87;
    --Ga5: #9499a0;
    --Ga5_t: #9499a0;
    --Ga6: #aeb3b9;
    --Ga6_t: #aeb3b9;
    --Ga7: #c9ccd0;
    --Ga7_t: #c9ccd0;
    --Ga8: #e3e5e7;
    --Ga8_t: #e3e5e7;
    --Ga9: #f1f2f3;
    --Ga9_t: #f1f2f3;
    --Ga10: #f6f7f8;
    --Ga10_t: #f6f7f8;
    --Ga11: #18191c;
    --Ga12: #2f3238;
    --Ga12_s: #18191c;
    --Ga13: #2f3238;
    --Ga13_s: #2f3238;
    --Wh0: #18191c;
    --Wh0_s: #18191c;
    --Wh0_t: #18191c;
    --Ba0: #ffffff;
    --Ba0_s: #ffffff;
    --Ba0_t: #ffffff;

    /* Pink - Darkened */
    --Pi0: #3f0723;
    --Pi1: #771141;
    --Pi2: #ad1c5b;
    --Pi3: #d03171;
    --Pi4: #e84b85;
    --Pi5: #ff6699;
    --Pi5_t: #ff6699;
    --Pi6: #ff8cb0;
    --Pi7: #ffb3ca;
    --Pi8: #ffd9e4;
    --Pi9: #ffecf1;
    --Pi10: #fff3f6;

    /* Magenta - Darkened */
    --Ma0: #330834;
    --Ma1: #670f67;
    --Ma2: #9b1797;
    --Ma3: #c525ba;
    --Ma4: #da41cb;
    --Ma5: #ee5ddb;
    --Ma6: #f286e2;
    --Ma7: #f7aeeb;
    --Ma8: #fbd7f4;
    --Ma9: #fdebfa;
    --Ma10: #fef3fc;

    /* Red - Darkened */
    --Re0: #3b060d;
    --Re1: #710e18;
    --Re2: #9f1922;
    --Re3: #c9272c;
    --Re4: #e23d3d;
    --Re5: #f85a54;
    --Re6: #fa857f;
    --Re7: #fcafaa;
    --Re8: #fdd7d4;
    --Re9: #feecea;
    --Re10: #fef3f2;

    /* Orange - Darkened */
    --Or0: #2f0c00;
    --Or1: #5e1b00;
    --Or2: #8d2d00;
    --Or3: #bb4100;
    --Or4: #e95b03;
    --Or5: #ff7f24;
    --Or6: #ffa058;
    --Or7: #ffc18f;
    --Or8: #ffe1c7;
    --Or9: #fff0e3;
    --Or10: #fff6ee;

    /* Yellow - Darkened */
    --Ye0: #2f1600;
    --Ye1: #5b2e00;
    --Ye2: #8a4a00;
    --Ye3: #c26e00;
    --Ye4: #fa9600;
    --Ye5: #ffb027;
    --Ye6: #ffc65d;
    --Ye7: #ffdb93;
    --Ye8: #ffeec9;
    --Ye9: #fff6e4;
    --Ye10: #fffaef;

    /* Light Yellow - Darkened */
    --Ly0: #2b1b00;
    --Ly1: #553900;
    --Ly2: #805a00;
    --Ly3: #aa7d00;
    --Ly4: #d5a300;
    --Ly5: #ffcc00;
    --Ly6: #ffdc40;
    --Ly7: #ffea80;
    --Ly8: #fff5bf;
    --Ly9: #fffadf;
    --Ly10: #fffcec;

    /* Light Green - Darkened */
    --Lg0: #102301;
    --Lg1: #224702;
    --Lg2: #376a03;
    --Lg3: #4e8e04;
    --Lg4: #66b105;
    --Lg5: #88cc24;
    --Lg6: #a9d95b;
    --Lg7: #c7e691;
    --Lg8: #e3f2c8;
    --Lg9: #f2f9e4;
    --Lg10: #f7fbef;

    /* Green - Darkened */
    --Gr0: #012414;
    --Gr1: #034926;
    --Gr2: #046e35;
    --Gr3: #089043;
    --Gr4: #0eb350;
    --Gr5: #2ac864;
    --Gr6: #5fd689;
    --Gr7: #95e4af;
    --Gr8: #caf1d6;
    --Gr9: #e4f8ea;
    --Gr10: #effbf3;

    /* Cyan - Darkened */
    --Cy0: #001d22;
    --Cy1: #013d44;
    --Cy2: #015f66;
    --Cy3: #018488;
    --Cy4: #02aaaa;
    --Cy5: #14c4bf;
    --Cy6: #4fd3d1;
    --Cy7: #89e1e1;
    --Cy8: #c4eff0;
    --Cy9: #e2f8f8;
    --Cy10: #edfbfb;

    /* Light Blue - Darkened */
    --Lb0: #001627;
    --Lb1: #002f4f;
    --Lb2: #004b76;
    --Lb3: #00699d;
    --Lb4: #008ac5;
    --Lb5: #00aeec;
    --Lb6: #40c5f1;
    --Lb7: #80daf6;
    --Lb8: #bfedfa;
    --Lb9: #dff6fd;
    --Lb10: #ecfafe;

    /* Blue - Darkened */
    --Bl0: #080d41;
    --Bl1: #121f7f;
    --Bl2: #2136ac;
    --Bl3: #3752c8;
    --Bl4: #4c6de4;
    --Bl5: #6188ff;
    --Bl6: #88a4ff;
    --Bl7: #b0c1ff;
    --Bl8: #d7dfff;
    --Bl9: #ebefff;
    --Bl10: #f3f5ff;

    /* Purple - Darkened */
    --Pu0: #190a44;
    --Pu1: #371683;
    --Pu2: #5627b3;
    --Pu3: #723ecc;
    --Pu4: #8f56e4;
    --Pu5: #ac6dff;
    --Pu6: #c392ff;
    --Pu7: #d8b6ff;
    --Pu8: #eddbff;
    --Pu9: #f6edff;
    --Pu10: #f9f4ff;

    /* Brown - Darkened */
    --Br0: #211815;
    --Br1: #423029;
    --Br2: #634a3e;
    --Br3: #856553;
    --Br4: #a5816a;
    --Br5: #c19d84;
    --Br6: #d0b7a3;
    --Br7: #e0cfc1;
    --Br8: #efe7e0;
    --Br9: #f7f3f0;
    --Br10: #faf8f6;

    /* Silver - Darkened */
    --Si0: #191e2b;
    --Si1: #323d54;
    --Si2: #4d5d7c;
    --Si3: #6d7f9c;
    --Si4: #8d9fb9;
    --Si5: #afc0d5;
    --Si6: #c3d0df;
    --Si7: #d7e0ea;
    --Si8: #ebeff4;
    --Si9: #f5f7fa;
    --Si10: #f9fbfc;

    /* RGB values for grayscale colors */
    --Ga0_rgb: 24, 25, 28;
    --Ga0_s_rgb: 24, 25, 28;
    --Ga1_rgb: 47, 50, 56;
    --Ga1_s_rgb: 47, 50, 56;
    --Ga2_rgb: 72, 76, 83;
    --Ga3_rgb: 97, 102, 109;
    --Ga5_rgb: 148, 153, 160;
    --Ga7_rgb: 201, 204, 208;
    --Ga10_rgb: 246, 247, 248;
    --Ga11_rgb: 24, 25, 28;
    --Ga12_rgb: 47, 50, 56;
    --Ga12_s_rgb: 24, 25, 28;
    --Ga13_rgb: 47, 50, 56;
    --Ga13_s_rgb: 47, 50, 56;
    --Wh0_rgb: 24, 25, 28;
    --Wh0_s_rgb: 24, 25, 28;
    --Ba0_rgb: 255, 255, 255;

    /* RGB values for other colors */
    --Pi1_rgb: 119, 17, 65;
    --Pi5_rgb: 255, 102, 153;
    --Re1_rgb: 113, 14, 24;
    --Re5_rgb: 248, 90, 84;
    --Or1_rgb: 94, 27, 0;
    --Or5_rgb: 255, 127, 36;
    --Ye1_rgb: 91, 46, 0;
    --Ye5_rgb: 255, 176, 39;
    --Ye6_rgb: 252, 198, 93;
    --Gr1_rgb: 3, 73, 38;
    --Gr5_rgb: 42, 200, 100;
    --Lb1_rgb: 0, 47, 79;
    --Lb5_rgb: 0, 174, 236;
    --Lb7_rgb: 128, 218, 246;
  }
`.trim()
