# Phone Access Setup Guide

## Problem
When you run the Flutter app on your phone, it can't connect to the server because it's trying to connect to `localhost` (which refers to the phone itself, not your computer).

## Solution

### Step 1: Find Your Computer's IP Address
1. **On Windows**: Double-click `find_ip.bat` or run `ipconfig` in Command Prompt
2. **On Mac/Linux**: Run `ifconfig` in Terminal
3. Look for an IP address that starts with:
   - `192.168.x.x` (most common)
   - `10.x.x.x`
   - `172.16.x.x` to `172.31.x.x`

### Step 2: Update Server Configuration
1. Open `backend/server.js`
2. The server is already configured to listen on all network interfaces (`0.0.0.0`)
3. Start the server: `node server.js`

### Step 3: Update App Configuration
1. Open `lib/config/server_config.dart`
2. Replace `192.168.1.100` with your computer's actual IP address:

```dart
static const String phoneUrl = 'http://YOUR_ACTUAL_IP:3000/api';
```

### Step 4: Test Connection
1. Make sure your phone and computer are on the same WiFi network
2. Run the app on your phone
3. Try to login - it should now connect to your computer's server

## Troubleshooting

### If it still doesn't work:
1. **Check Windows Firewall**: Allow Node.js through Windows Firewall
2. **Check Antivirus**: Some antivirus software blocks network connections
3. **Check Router**: Some routers block local network connections

### To allow Node.js through Windows Firewall:
1. Open Windows Defender Firewall
2. Click "Allow an app or feature through Windows Defender Firewall"
3. Click "Change settings"
4. Click "Allow another app"
5. Browse to your Node.js installation (usually `C:\Program Files\nodejs\node.exe`)
6. Make sure both Private and Public are checked

### Alternative: Use ngrok (for testing)
If you can't get local network access working:
1. Install ngrok: `npm install -g ngrok`
2. Start your server: `node server.js`
3. In another terminal: `ngrok http 3000`
4. Use the ngrok URL in your app configuration

## Quick Test
Run this command to test if your server is accessible:
```bash
curl http://YOUR_COMPUTER_IP:3000/api/test
```

You should see: `{"success":true,"message":"Server is running",...}`

## Network Test Screen
I've added a Network Test Screen to help debug connectivity issues:

1. **Add the screen to your app**: Import and navigate to `NetworkTestScreen`
2. **Test all connections**: The screen will test:
   - Internet connectivity (Google, GitHub, etc.)
   - Local network connectivity
   - Server connection
3. **View results**: See which connections are working and which are failing

To add the Network Test Screen to your app, you can add a button in your settings or login screen:

```dart
// In your settings or login screen
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NetworkTestScreen()),
    );
  },
  child: Text('Test Network Connection'),
)
```
