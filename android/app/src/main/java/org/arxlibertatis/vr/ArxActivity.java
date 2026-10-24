/*
 * Copyright 2026 Arx Libertatis VR contributors <kazakov.s.fl@gmail.com>
 *
 * This file is part of Arx Libertatis.
 *
 * Arx Libertatis is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Arx Libertatis is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Arx Libertatis.  If not, see <http://www.gnu.org/licenses/>.
 */

package org.arxlibertatis.vr;

import android.Manifest;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.res.AssetManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.Settings;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.concurrent.CountDownLatch;

import org.libsdl.app.SDLActivity;

/**
 * Starts the game with the data, config and save folder in /sdcard/ArxLibertatis, or in the app folder
 * (/sdcard/Android/data/<package>/files) when "All files access" is not granted.
 *
 * The native code runs on the SDL thread, which calls getArguments() first: it waits there until the storage
 * permission prompt is answered.
 */
public class ArxActivity extends SDLActivity {

	private static final String TAG = "arx";
	private static final String SHARED_FOLDER = "ArxLibertatis";
	private static final String ASKED_STORAGE = "askedStorage";
	private static final int STORAGE_REQUEST = 1;

	private final CountDownLatch mStorageAnswered = new CountDownLatch(1);
	private boolean mAskingStorage;
	private boolean mLeftForSettings;

	@Override
	protected String[] getLibraries() {
		return new String[] { "SDL2", "openal", "main" };
	}

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		if(!hasSharedStorage() && askForStorage()) {
			mAskingStorage = true;
		} else {
			mStorageAnswered.countDown();
		}
	}

	@Override
	protected void onDestroy() {
		// Stops the game thread (SDLActivity waits for it)
		super.onDestroy();
		// Android keeps the process for the next start, but the game's global state can't be reused: the next start
		// ran into the player and resources of the previous game and crashed
		System.exit(0);
	}

	@Override
	protected void onPause() {
		super.onPause();
		if(mAskingStorage) {
			mLeftForSettings = true;
		}
	}

	@Override
	protected void onResume() {
		super.onResume();
		if(mAskingStorage && mLeftForSettings && Build.VERSION.SDK_INT >= 30) {
			mAskingStorage = false;
			mStorageAnswered.countDown();
		}
	}

	@Override
	public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults);
		if(requestCode == STORAGE_REQUEST) {
			mAskingStorage = false;
			mStorageAnswered.countDown();
		}
	}

	@Override
	protected String[] getArguments() {

		try {
			mStorageAnswered.await();
		} catch(InterruptedException e) {
			Thread.currentThread().interrupt();
		}

		File folder = getDataFolder();
		Log.i(TAG, "Data folder: " + folder);

		File core = extractCoreData();

		// The folder is also searched for the .pak files and loose override folders (graph, game, ...)
		if(core != null) {
			return new String[] {
				"--no-data-dir", "--data-dir", core.getPath(), "--user-dir", folder.getPath(), "--config-dir", folder.getPath()
			};
		}
		return new String[] { "--no-data-dir", "--user-dir", folder.getPath(), "--config-dir", folder.getPath() };
	}

	private boolean hasSharedStorage() {
		if(Build.VERSION.SDK_INT >= 30) {
			return Environment.isExternalStorageManager();
		}
		return checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED;
	}

	// Ask once for the shared folder, the user can still grant it later in the app settings
	private boolean askForStorage() {

		SharedPreferences preferences = getPreferences(MODE_PRIVATE);
		if(preferences.getBoolean(ASKED_STORAGE, false)) {
			return false;
		}
		preferences.edit().putBoolean(ASKED_STORAGE, true).apply();

		if(Build.VERSION.SDK_INT < 30) {
			requestPermissions(new String[] { Manifest.permission.WRITE_EXTERNAL_STORAGE }, STORAGE_REQUEST);
			return true;
		}

		Intent intent = new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
		                           Uri.parse("package:" + getPackageName()));
		try {
			startActivity(intent);
			return true;
		} catch(ActivityNotFoundException e) {
			Log.w(TAG, "No settings screen for all files access");
			return false;
		}
	}

	private File getDataFolder() {

		if(hasSharedStorage()) {
			File folder = new File(Environment.getExternalStorageDirectory(), SHARED_FOLDER);
			if(folder.isDirectory() || folder.mkdirs()) {
				return folder;
			}
			Log.w(TAG, "Could not create " + folder);
		}

		File folder = getExternalFilesDir(null);
		if(folder == null) {
			folder = getFilesDir();
		}
		return folder;
	}

	// Copy Arx Libertatis' own data files (localisation, fonts) out of the APK after each install or update
	private File extractCoreData() {

		File core = new File(getFilesDir(), "core");
		File stamp = new File(core, ".version");
		String version;
		try {
			PackageInfo info = getPackageManager().getPackageInfo(getPackageName(), 0);
			version = info.versionName + "-" + info.lastUpdateTime;
		} catch(PackageManager.NameNotFoundException e) {
			version = "unknown";
		}

		if(stamp.isFile() && version.equals(readText(stamp))) {
			return core;
		}

		deleteRecursive(core);
		try {
			copyAssets(getAssets(), "core", core);
			writeText(stamp, version);
		} catch(IOException e) {
			Log.e(TAG, "Could not extract the core data: " + e);
			return null;
		}

		return core;
	}

	private static void copyAssets(AssetManager assets, String path, File target) throws IOException {
		String[] children = assets.list(path);
		if(children == null || children.length == 0) {
			try(InputStream in = assets.open(path); OutputStream out = new FileOutputStream(target)) {
				byte[] buffer = new byte[65536];
				int count;
				while((count = in.read(buffer)) > 0) {
					out.write(buffer, 0, count);
				}
			}
			return;
		}
		if(!target.isDirectory() && !target.mkdirs()) {
			throw new IOException("Could not create " + target);
		}
		for(String child : children) {
			copyAssets(assets, path + "/" + child, new File(target, child));
		}
	}

	private static void deleteRecursive(File file) {
		File[] children = file.listFiles();
		if(children != null) {
			for(File child : children) {
				deleteRecursive(child);
			}
		}
		if(file.exists() && !file.delete()) {
			Log.w(TAG, "Could not delete " + file);
		}
	}

	private static String readText(File file) {
		try(InputStream in = new FileInputStream(file)) {
			byte[] data = new byte[(int)file.length()];
			int length = in.read(data);
			return new String(data, 0, Math.max(length, 0), "UTF-8");
		} catch(IOException e) {
			return "";
		}
	}

	private static void writeText(File file, String text) throws IOException {
		try(OutputStream out = new FileOutputStream(file)) {
			out.write(text.getBytes("UTF-8"));
		}
	}

}
