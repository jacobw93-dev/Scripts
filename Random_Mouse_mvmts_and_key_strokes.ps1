Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class UserInput
{
[DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint cButtons, uint dwExtraInfo);
[DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, uint dwExtraInfo);
public const int MOUSEEVENTF_MOVE = 0x0001;
public const int MOUSEEVENTF_LEFTDOWN = 0x0002;
public const int MOUSEEVENTF_LEFTUP = 0x0004;
public const int MOUSEEVENTF_RIGHTDOWN = 0x0008;
public const int MOUSEEVENTF_RIGHTUP = 0x0010;
public const int MOUSEEVENTF_MIDDLEDOWN = 0x0020;
public const int MOUSEEVENTF_MIDDLEUP = 0x0040;
public const int MOUSEEVENTF_ABSOLUTE = 0x8000;
public const int KEYEVENTF_KEYDOWN = 0x0000;
public const int KEYEVENTF_KEYUP = 0x0002;
public static void MoveMouse(int xDelta, int yDelta)
{
mouse_event(MOUSEEVENTF_MOVE, (uint)xDelta, (uint)yDelta, 0, 0);
}
public static void ClickLeftMouseButton()
{
mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
}
public static void ClickRightMouseButton()
{
mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0);
mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0);
}
public static void PressKey(byte keyCode)
{
keybd_event(keyCode, 0, KEYEVENTF_KEYDOWN, 0);
keybd_event(keyCode, 0, KEYEVENTF_KEYUP, 0);
}
}
"@
function GenerateRandomMovement
{
$maxMouseDelta = 50 # Maksymalna odległość o jaką poruszy się myszka (w pikselach)
$maxKeyPresses = 10 # Maksymalna liczba naciśnięć klawisza
$random = New-Object System.Random
# Generowanie losowego ruchu myszką
$xDelta = $random.Next(-$maxMouseDelta, $maxMouseDelta + 1)
$yDelta = $random.Next(-$maxMouseDelta, $maxMouseDelta + 1)
[UserInput]::MoveMouse($xDelta, $yDelta)
# Losowe naciśnięcia klawiszy
$numKeyPresses = $random.Next(1, $maxKeyPresses + 1)
for ($i = 0; $i -lt $numKeyPresses; $i++)
{
$keyCode = $random.Next(65, 91) # Generowanie losowego kodu klawisza A-Z (ASCII 65-90)
[UserInput]::PressKey($keyCode)
}
}
# Wygenerowanie ruchu co 5 sekund
while ($true)
{
GenerateRandomMovement
Start-Sleep -Seconds 5
}
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class UserInput
{
[DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint cButtons, uint dwExtraInfo);
[DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, uint dwExtraInfo);
public const int MOUSEEVENTF_MOVE = 0x0001;
public const int MOUSEEVENTF_LEFTDOWN = 0x0002;
public const int MOUSEEVENTF_LEFTUP = 0x0004;
public const int MOUSEEVENTF_RIGHTDOWN = 0x0008;
public const int MOUSEEVENTF_RIGHTUP = 0x0010;
public const int MOUSEEVENTF_MIDDLEDOWN = 0x0020;
public const int MOUSEEVENTF_MIDDLEUP = 0x0040;
public const int MOUSEEVENTF_ABSOLUTE = 0x8000;
public const int KEYEVENTF_KEYDOWN = 0x0000;
public const int KEYEVENTF_KEYUP = 0x0002;
public static void MoveMouse(int xDelta, int yDelta)
{
mouse_event(MOUSEEVENTF_MOVE, (uint)xDelta, (uint)yDelta, 0, 0);
}
public static void ClickLeftMouseButton()
{
mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
}
public static void ClickRightMouseButton()
{
mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0);
mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0);
}
public static void PressKey(byte keyCode)
{
keybd_event(keyCode, 0, KEYEVENTF_KEYDOWN, 0);
keybd_event(keyCode, 0, KEYEVENTF_KEYUP, 0);
}
}
"@
function GenerateRandomMovement
{
$maxMouseDelta = 50 # Maksymalna odległość o jaką poruszy się myszka (w pikselach)
$maxKeyPresses = 10 # Maksymalna liczba naciśnięć klawisza
$random = New-Object System.Random
# Generowanie losowego ruchu myszką
$xDelta = $random.Next(-$maxMouseDelta, $maxMouseDelta + 1)
$yDelta = $random.Next(-$maxMouseDelta, $maxMouseDelta + 1)
[UserInput]::MoveMouse($xDelta, $yDelta)
# Losowe naciśnięcia klawiszy
$numKeyPresses = $random.Next(1, $maxKeyPresses + 1)
for ($i = 0; $i -lt $numKeyPresses; $i++)
{
$keyCode = $random.Next(65, 91) # Generowanie losowego kodu klawisza A-Z (ASCII 65-90)
[UserInput]::PressKey($keyCode)
}
}
# Wygenerowanie ruchu co 5 sekund
while ($true)
{
GenerateRandomMovement
Start-Sleep -Seconds 5
}
