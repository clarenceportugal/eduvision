# EduVision MongoDB Setup Guide

## Database Structure
- **Database Name**: `eduvision`
- **Collection Name**: `users`
- **Connection URI**: `mongodb+srv://saynoseanniel:mathematics10@cluster0.crfzw.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0`

## User Collection Schema
Each user document in the `users` collection should have this structure:

```json
{
  "_id": ObjectId("..."),
  "email": "student@university.edu",
  "password": "user_password",
  "studentId": "STU12345",
  "name": "Student Full Name",
  "program": "Computer Science",
  "yearLevel": "3rd Year"
}
```

### Required Fields:
- `email`: User's email address
- `password`: User's password (store hashed in production)

### Optional Fields:
- `studentId`: Student ID number
- `name`: Full name of the user
- `program`: Academic program
- `yearLevel`: Current year level

## Backend Server Setup

1. **Navigate to backend directory:**
   ```bash
   cd backend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Test password hashing (optional):**
   ```bash
   node test-password.js
   ```

4. **Start the server:**
   ```bash
   npm start
   # OR for development with auto-reload:
   npm run dev
   ```

5. **Server will run on:**
   ```
   http://localhost:3000
   ```

## Password Hashing Support

The backend automatically detects and handles these password formats:

- **bcrypt**: `$2a$10$...` (recommended, most secure)
- **MD5**: `5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721dce` (32 hex chars)
- **SHA1**: `aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d` (40 hex chars)  
- **SHA256**: `ef92b778bafe771e89245b89ecbc08a44a4e166c06659911881f383d4473e94f3` (64 hex chars)
- **Plain text**: Not recommended but supported

## Debug Password Format

To check what hashing method your database uses:

```bash
curl -X POST http://localhost:3000/api/debug-password \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com"}'
```

## API Endpoints

### POST /api/login
**Request:**
```json
{
  "emailOrStudentId": "student@university.edu",
  "password": "user_password"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Login successful",
  "user": {
    "_id": "...",
    "email": "student@university.edu",
    "studentId": "STU12345",
    "name": "Student Name",
    "program": "Computer Science",
    "yearLevel": "3rd Year"
  },
  "token": "auth_token_here"
}
```

**Error Response (401):**
```json
{
  "success": false,
  "message": "Invalid credentials"
}
```

### GET /api/test
Tests the MongoDB connection and returns server status.

## Sample User Data

Add these sample users to your MongoDB `eduvision.users` collection for testing:

```json
[
  {
    "email": "student1@university.edu",
    "password": "password123",
    "studentId": "STU001",
    "name": "John Doe",
    "program": "Computer Science",
    "yearLevel": "3rd Year"
  },
  {
    "email": "student2@university.edu",
    "password": "mypassword",
    "studentId": "STU002",
    "name": "Jane Smith",
    "program": "Information Technology",
    "yearLevel": "2nd Year"
  },
  {
    "email": "admin@university.edu",
    "password": "admin123",
    "studentId": "ADMIN001",
    "name": "Admin User",
    "program": "Administration",
    "yearLevel": "Staff"
  }
]
```

## Flutter App Configuration

The Flutter app will:
1. Try to connect to the backend API first
2. Fall back to demo mode if the server is unavailable
3. Store user session locally using SharedPreferences

## Security Notes

⚠️ **For Production:**
1. Hash passwords using bcrypt
2. Use JWT tokens for authentication
3. Add rate limiting
4. Use HTTPS
5. Validate input data
6. Add proper error handling

## Troubleshooting

1. **Connection Issues:**
   - Make sure the backend server is running
   - Check if MongoDB Atlas allows connections from your IP
   - Verify the connection string is correct

2. **CORS Issues:**
   - The backend includes CORS middleware
   - For mobile apps, CORS typically isn't an issue

3. **Demo Mode:**
   - If the server is unavailable, the app falls back to demo authentication
   - Any non-empty credentials with password length ≥ 3 will work in demo mode