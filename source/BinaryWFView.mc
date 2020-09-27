using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Time.Gregorian as Calendar;
using Toybox.Time;
using Toybox.ActivityMonitor;
using Toybox.Activity;

class BinaryWFView extends WatchUi.WatchFace {


    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    var heartFilled;
    var heartFilledCurrent;
    var heartFilledOld;
    var heartOutlined;
    var batteryFilled;
    var batteryOutlined;
    var backgroundLoader;
    var weekdayBitmap;

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
        heartFilled = WatchUi.loadResource(Rez.Drawables.HeartFilledMedium);
        heartFilledCurrent = WatchUi.loadResource(Rez.Drawables.HeartFilledMediumCurrent);
        heartFilledOld = WatchUi.loadResource(Rez.Drawables.HeartFilledMediumOld);
        heartOutlined = WatchUi.loadResource(Rez.Drawables.HeartOutlinedMedium);
        batteryFilled = WatchUi.loadResource(Rez.Drawables.BatteryFilled);
        batteryOutlined = WatchUi.loadResource(Rez.Drawables.BatteryOutlined);
        weekdayBitmap = new WeekdayBitmap();
    }

    // Update the view
    function onUpdate(dc) {
        View.onUpdate(dc);

        // Get and show the current time
        var now = Calendar.info(Time.now(), Time.FORMAT_SHORT);
        var day = now.day;
        var month = now.month;
        var year = now.year;
        var hour = now.hour;
        var minute = now.min;

        var roundMargin = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND ? dc.getHeight() / 10 : 0;
        var batteryHeight = batteryFilled.getHeight();
        var heartHeight = heartFilled.getHeight();
        var timeRadius = 12;
        var dateRadius = 4;
        var stepsRadius = 3;
        var freeSpace = dc.getHeight() - batteryHeight - heartHeight - 5*timeRadius - 2*dateRadius - 2*stepsRadius - 2*roundMargin;

        var smallSpacer = (freeSpace / 8.5).toLong();
        var mediumSpacer = (freeSpace / 6).toLong();
        var largeSpacer = (freeSpace / 3.3).toLong();

        var battery = System.getSystemStats().battery.toLong();
        var batteryTop = smallSpacer + roundMargin;
        new BinaryBitmap(dc, batteryTop, 4, 7, 0, batteryFilled, batteryOutlined).drawBinary(battery);

        var heartRate = getHeartRate();
        var heartOne = heartFilled;
        var hrTop = batteryTop + largeSpacer;
        var heartRateAge = heartRate["age"];
        if (heartRateAge == 0) {
            heartOne = heartFilledCurrent;
        } else if (heartRateAge > 30) {
            heartOne = heartFilledOld;
        }
        new BinaryBitmap(dc, hrTop, 4, 8, 0, heartOne, heartOutlined).drawBinary(heartRate["heartRate"]);

        var timeTop = hrTop + largeSpacer;
        var weekDayStart = dc.getWidth() / 2 - 8.3 * timeRadius;
        weekdayBitmap.getBitmap(now.day_of_week, weekDayStart, hrTop + mediumSpacer).draw(dc);

        new BinaryCircle(dc, timeRadius * 2, timeTop, timeRadius, 5, Graphics.COLOR_GREEN, timeRadius * 1.5).drawBinary(hour);
        new BinaryCircle(dc, timeRadius * 2, timeTop + 3 * timeRadius, timeRadius, 6, Graphics.COLOR_PINK, 0).drawBinary(minute);

        var dateTop = timeTop + 5 * timeRadius + mediumSpacer;
        new BinaryCircle(dc, dateRadius * 2, dateTop, dateRadius, 5, 0x00FFFF, - (4 * 3 * dateRadius)).drawBinary(day);
        new BinaryCircle(dc, dateRadius * 2, dateTop, dateRadius, 4, 0x00FFFF, 4 * 3 * dateRadius).drawBinary(month);

        var amInfo = ActivityMonitor.getInfo();
        var steps = ((amInfo.steps.toFloat() / amInfo.stepGoal) * 100).toLong();
        var stepsTop = dateTop + 2 * dateRadius + mediumSpacer;
        new BinaryCircle(dc, stepsRadius * 2, stepsTop, stepsRadius, 9, 0xFF3333, 0).drawBinary(steps);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
    }

    function getHeartRate() {
        var heartRate = Activity.getActivityInfo().currentHeartRate;
        if (heartRate != null) {
            return { "heartRate" => heartRate, "age" => 0 };
        }

        var history = ActivityMonitor.getHeartRateHistory(1, true);
        var sample = history.next();
        var maxAge = new Time.Duration(90);
        var now = Time.now();
        if (sample != null && sample != ActivityMonitor.INVALID_HR_SAMPLE && now.subtract(sample.when).lessThan(maxAge)) {
            return {"heartRate" => sample.heartRate, "age" => now.subtract(sample.when).value()};
        }

        return {"heartRate" => null, "age" => -1};
    }
}

class BinaryCircle {

    protected var dc;
    protected var size;
    protected var y;
    protected var x;
    protected var digits;
    protected var color;
    protected var spacing;

    function initialize(dc, size, y, spacing, digits, color, offset) {
        me.dc = dc;
        me.size = size;
        me.y = y;
        var width = dc.getWidth();
        var space = digits * size + (digits - 1) * spacing;
        me.x = (width - space) / 2 + offset;
        me.digits = digits;
        me.color = color;
        me.spacing = spacing;
    }

    function drawBinary(value) {
        if (value == null) {
            drawMissing(x, y);
            return;
        }
        var radius = size / 2;
        for (var i = 0; i < digits; i++) {
            var bit = value & (1 << i);
            var xDigit = x + (digits - i - 1) * (size + spacing);
            if (bit) {
                drawOne(xDigit, y, size);
            } else {
                drawZero(xDigit, y, size);
            }
        }
    }

    protected function drawOne(xTop, yTop, size) {
        var radius = size / 2;
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.fillCircle(xTop + radius, yTop + radius, radius);
    }

    protected function drawZero(xTop, yTop, size) {
         var radius = size / 2;
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.drawCircle(xTop + radius, yTop + radius, radius);
    }

    protected function drawMissing(xTop, yTop) {
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
        var start = xTop + (digits -1) * (size + spacing);
        dc.drawLine(start, yTop + (size / 2), start - size, yTop + (size / 2));
    }
}

class BinaryBitmap extends BinaryCircle {
    private var zeroBitmap;
    private var oneBitmap;

    function initialize(dc, y, spacing, digits, offset, one, zero) {
        me.dc = dc;
        me.oneBitmap = one;
        me.zeroBitmap = zero;
        me.size = oneBitmap.getWidth();
        me.y = y;
        var width = dc.getWidth();
        var space = digits * size + (digits - 1) * spacing;
        me.x = (width - space) / 2 + offset;
        me.digits = digits;
        me.color = color;
        me.spacing = spacing;
    }

    protected function drawOne(xTop, yTop, size) {
         dc.drawBitmap(xTop, yTop, oneBitmap);
    }

    protected function drawZero(xTop, yTop, size) {
         dc.drawBitmap(xTop, yTop, zeroBitmap);
    }
}

class WeekdayBitmap {
    private var index;
    private var bitmap;
    var resources = [
        Rez.Drawables.Sunday,
        Rez.Drawables.Monday,
        Rez.Drawables.Tuesday,
        Rez.Drawables.Wednesday,
        Rez.Drawables.Thursday,
        Rez.Drawables.Friday,
        Rez.Drawables.Saturday
     ];

    public function getBitmap(weekday, x, y) {
        if (index != weekday) {
          index = weekday;
          System.println(index);
          bitmap = null;
          bitmap = new WatchUi.Bitmap({
                :rezId=>resources[ index -1 ],
                :locX=>x,
                :locY=>y,
            });
        }
        return bitmap;
    }
}

