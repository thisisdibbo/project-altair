// Applies the few platform settings the app needs to the android/ and ios/
// folders that `flutter create` generates. Safe to run more than once.
//
//   node tools/setup-platforms.mjs      (run it from the project folder)

import { existsSync, readFileSync, writeFileSync } from "node:fs";

const APP_NAME = "Project Altair";
let changed = 0;

function patch(file, edit) {
  if (!existsSync(file)) {
    console.log(`skip   ${file} (not found - run "flutter create" first)`);
    return;
  }
  const before = readFileSync(file, "utf8");
  const after = edit(before);
  if (after === before) {
    console.log(`ok     ${file} (already set)`);
    return;
  }
  writeFileSync(file, after);
  changed++;
  console.log(`patch  ${file}`);
}

// Android: the name under the icon, and internet access in release builds.
patch("android/app/src/main/AndroidManifest.xml", (xml) => {
  let out = xml.replace(/android:label="[^"]*"/, `android:label="${APP_NAME}"`);
  if (!out.includes("android.permission.INTERNET")) {
    out = out.replace(
      /(<manifest[^>]*>)/,
      `$1\n    <uses-permission android:name="android.permission.INTERNET"/>`,
    );
  }
  return out;
});

// iOS: display name and the two photo permission messages iOS requires
// before the camera or gallery opens.
patch("ios/Runner/Info.plist", (plist) => {
  let out = plist.replace(
    /(<key>CFBundleDisplayName<\/key>\s*<string>)[^<]*(<\/string>)/,
    `$1${APP_NAME}$2`,
  );
  const additions = [
    [
      "NSCameraUsageDescription",
      "<string>Take a profile picture for a team member.</string>",
    ],
    [
      "NSPhotoLibraryUsageDescription",
      "<string>Choose a profile picture for a team member.</string>",
    ],
  ];
  let block = "";
  for (const [key, value] of additions) {
    if (!out.includes(`<key>${key}</key>`)) {
      block += `\t<key>${key}</key>\n\t${value}\n`;
    }
  }
  if (block) {
    const end = out.lastIndexOf("</dict>");
    out = out.slice(0, end) + block + out.slice(end);
  }
  return out;
});

console.log(changed ? `\nDone - ${changed} file(s) updated.` : "\nNothing to change.");
