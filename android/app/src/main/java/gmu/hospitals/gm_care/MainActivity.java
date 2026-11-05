package gmu.hospitals.gm_care;

import android.content.Intent;
import android.net.Uri;
import android.provider.CalendarContract;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterFragmentActivity {
    private static final String CHANNEL = "com.gmcare.hospital/calendar";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if (call.method.equals("addToCalendar")) {
                    try {
                        String title = call.argument("title");
                        String location = call.argument("location");
                        String description = call.argument("description");
                        Long startTime = call.argument("startTime");
                        Long endTime = call.argument("endTime");

                        Intent intent = new Intent(Intent.ACTION_INSERT)
                            .setData(CalendarContract.Events.CONTENT_URI)
                            .putExtra(CalendarContract.Events.TITLE, title)
                            .putExtra(CalendarContract.Events.EVENT_LOCATION, location)
                            .putExtra(CalendarContract.Events.DESCRIPTION, description)
                            .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startTime != null ? startTime : System.currentTimeMillis())
                            .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endTime != null ? endTime : (System.currentTimeMillis() + 3600000));

                        startActivity(intent);
                        result.success(true);
                    } catch (Exception e) {
                        result.error("CALENDAR_ERROR", e.getMessage(), null);
                    }
                } else if (call.method.equals("openDialer")) {
                    try {
                        String phone = call.argument("phone");
                        Intent dialIntent = new Intent(Intent.ACTION_DIAL);
                        dialIntent.setData(Uri.parse("tel:" + (phone != null ? phone.replaceAll("[^0-9+]", "") : "")));
                        startActivity(dialIntent);
                        result.success(true);
                    } catch (Exception e) {
                        result.error("DIALER_ERROR", e.getMessage(), null);
                    }
                } else if (call.method.equals("openUrl")) {
                    try {
                        String url = call.argument("url");
                        if (url != null && !url.isEmpty()) {
                            if (!url.startsWith("http://") && !url.startsWith("https://")) {
                                url = "https://" + url;
                            }
                            Intent browserIntent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
                            startActivity(browserIntent);
                            result.success(true);
                        } else {
                            result.error("URL_EMPTY", "URL was empty", null);
                        }
                    } catch (Exception e) {
                        result.error("BROWSER_ERROR", e.getMessage(), null);
                    }
                } else {
                    result.notImplemented();
                }
            });
    }
}
