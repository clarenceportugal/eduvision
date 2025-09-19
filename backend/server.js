const express = require('express');
const { MongoClient, ObjectId } = require('mongodb');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const cloudinary = require('cloudinary').v2;
const multer = require('multer');

const app = express();
const port = process.env.PORT || 10000;

// MongoDB connection details
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb+srv://saynoseanniel:mathematics10@cluster0.crfzw.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0';
const DATABASE_NAME = process.env.DATABASE_NAME || 'eduvision';
const COLLECTION_NAME = process.env.COLLECTION_NAME || 'users';

// Cloudinary configuration
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME || 'deqtxoewp',
  api_key: process.env.CLOUDINARY_API_KEY || '429458566368881',
  api_secret: process.env.CLOUDINARY_API_SECRET || '1NPDJVTgxydH8VCOD7w-NLhFVdc'
});

// Configure multer for handling multipart/form-data
const storage = multer.memoryStorage();
const upload = multer({ 
  storage: storage,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB limit
  },
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'), false);
    }
  }
});

let db;

// Middleware
app.use(cors());
app.use(express.json());

// Connect to MongoDB
MongoClient.connect(MONGODB_URI)
  .then(client => {
    console.log('Connected to MongoDB');
    db = client.db(DATABASE_NAME);
  })
  .catch(error => console.error('MongoDB connection error:', error));

// Login endpoint
app.post('/api/login', async (req, res) => {
  try {
    const { emailOrStudentId, password } = req.body;

    if (!emailOrStudentId || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email/Username and password are required'
      });
    }

    // Find user by email or username
    console.log('Attempting login with:', emailOrStudentId);
    
    const user = await db.collection(COLLECTION_NAME).findOne({
      $or: [
        { email: emailOrStudentId },
        { username: emailOrStudentId }
      ]
    });
    
    console.log('User found:', user ? 'YES' : 'NO');
    if (user) {
      console.log('User fields:', Object.keys(user));
      console.log('User email:', user.email);
      console.log('User username:', user.username || 'NO_USERNAME');
      console.log('User first_name:', user.first_name || 'NO_FIRST_NAME');
      console.log('User middle_name:', user.middle_name || 'NO_MIDDLE_NAME');
      console.log('User last_name:', user.last_name || 'NO_LAST_NAME');
    }

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Check password - handle multiple hashing methods
    const isPasswordValid = await verifyPassword(password, user.password);

    if (!isPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Remove password from response and ensure we have a name field
    const { password: _, ...userWithoutPassword } = user;
    
    // Try to get a display name from various possible fields
    let displayName = '';
    if (user.first_name) {
      displayName = user.first_name;
      if (user.middle_name) {
        displayName += ` ${user.middle_name}`;
      }
      if (user.last_name) {
        displayName += ` ${user.last_name}`;
      }
    } else {
      displayName = user.name || 
                    user.fullName || 
                    user.username || 
                    user.email?.split('@')[0] || 
                    'User';
    }
    userWithoutPassword.displayName = displayName;

    // Add role field with fallback to 'Instructor'
    userWithoutPassword.role = user.role || user.userType || 'Instructor';

    console.log('Login successful for user:', userWithoutPassword.email);
    console.log('Available fields:', Object.keys(user));
    console.log('Display name:', userWithoutPassword.displayName);
    console.log('User role:', userWithoutPassword.role);

    res.json({
      success: true,
      message: 'Login successful',
      user: userWithoutPassword,
      token: generateToken(user._id) // You can implement JWT token generation
    });

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Update profile endpoint
app.put('/api/profile/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const updateData = req.body;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: 'User ID is required'
      });
    }

    // Remove sensitive fields that shouldn't be updated via this endpoint
    const { password, _id, ...allowedUpdates } = updateData;

    // If first_name, middle_name, or last_name are provided, update displayName
    if (allowedUpdates.first_name !== undefined || 
        allowedUpdates.middle_name !== undefined || 
        allowedUpdates.last_name !== undefined) {
      
      // Get current user data to construct full name
      const currentUser = await db.collection(COLLECTION_NAME).findOne({ _id: new ObjectId(userId) });
      
      const firstName = allowedUpdates.first_name || currentUser?.first_name || '';
      const middleName = allowedUpdates.middle_name || currentUser?.middle_name || '';
      const lastName = allowedUpdates.last_name || currentUser?.last_name || '';
      
      let displayName = firstName;
      if (middleName) {
        displayName += ` ${middleName}`;
      }
      if (lastName) {
        displayName += ` ${lastName}`;
      }
      
      allowedUpdates.displayName = displayName;
      allowedUpdates.name = displayName;
      allowedUpdates.fullName = displayName;
    }

    console.log('Updating user profile:', userId);
    console.log('Update data:', allowedUpdates);

    // Update user in database
    const result = await db.collection(COLLECTION_NAME).updateOne(
      { _id: new ObjectId(userId) },
      { $set: allowedUpdates }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Get updated user data
    const updatedUser = await db.collection(COLLECTION_NAME).findOne({ _id: new ObjectId(userId) });
    const { password: _, ...userWithoutPassword } = updatedUser;

    console.log('Profile updated successfully for user:', updatedUser.email);

    res.json({
      success: true,
      message: 'Profile updated successfully',
      user: userWithoutPassword
    });

  } catch (error) {
    console.error('Profile update error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Change password endpoint
app.put('/api/change-password/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const { currentPassword, newPassword } = req.body;

    console.log('=== Change Password Request ===');
    console.log('User ID:', userId);
    console.log('Has current password:', !!currentPassword);
    console.log('Has new password:', !!newPassword);
    console.log('New password length:', newPassword?.length);

    if (!userId || !currentPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        message: 'User ID, current password, and new password are required'
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'New password must be at least 6 characters long'
      });
    }

    console.log('Attempting password change for user:', userId);

    // Find user by ID - handle both ObjectId and string formats
    let user;
    try {
      // Try as ObjectId first
      user = await db.collection(COLLECTION_NAME).findOne({ _id: new ObjectId(userId) });
    } catch (error) {
      // If ObjectId fails, try as string (for demo mode)
      console.log('ObjectId failed, trying as string:', error.message);
      user = await db.collection(COLLECTION_NAME).findOne({ _id: userId });
    }
    
    if (!user) {
      console.log('User not found in database for ID:', userId);
      console.log('This might be a demo user. Checking if it\'s a demo session...');
      
      // Check if it's a demo user (demo users have predictable IDs)
      if (userId === '675a1b2c3d4e5f6789abcdef') {
        console.log('Demo user detected, simulating password change...');
        
        // For demo mode, simulate basic validation
        if (currentPassword.length < 3) {
          return res.status(401).json({
            success: false,
            message: 'Current password is incorrect'
          });
        }
        
        // Simulate success without database operations
        return res.json({
          success: true,
          message: 'Password changed successfully (Demo Mode)'
        });
      }
      
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    console.log('User found for password change:', user.email);

    // Verify current password
    const isCurrentPasswordValid = await verifyPassword(currentPassword, user.password);

    if (!isCurrentPasswordValid) {
      return res.status(401).json({
        success: false,
        message: 'Current password is incorrect'
      });
    }

    // Hash new password using bcrypt (recommended)
    const saltRounds = 12;
    const hashedNewPassword = await bcrypt.hash(newPassword, saltRounds);

    console.log('Updating password for user:', user.email);
    console.log('New password hashed successfully. Hash length:', hashedNewPassword.length);
    console.log('Hash starts with bcrypt identifier:', hashedNewPassword.startsWith('$2'));

    // Update password in database - handle both ObjectId and string formats
    let result;
    try {
      // Try as ObjectId first
      result = await db.collection(COLLECTION_NAME).updateOne(
        { _id: new ObjectId(userId) },
        { 
          $set: { 
            password: hashedNewPassword,
            passwordUpdatedAt: new Date()
          }
        }
      );
    } catch (error) {
      // If ObjectId fails, try as string (for demo mode)
      console.log('Update ObjectId failed, trying as string:', error.message);
      result = await db.collection(COLLECTION_NAME).updateOne(
        { _id: userId },
        { 
          $set: { 
            password: hashedNewPassword,
            passwordUpdatedAt: new Date()
          }
        }
      );
    }

    if (result.matchedCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    console.log('Password updated successfully for user:', user.email);
    console.log('Database update result - matched:', result.matchedCount, 'modified:', result.modifiedCount);

    res.json({
      success: true,
      message: 'Password changed successfully'
    });

  } catch (error) {
    console.error('=== Change Password Error ===');
    console.error('Error type:', error.name);
    console.error('Error message:', error.message);
    console.error('Full error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error: ' + error.message
    });
  }
});

// Test connection endpoint
app.get('/api/test', (req, res) => {
  res.json({
    success: true,
    message: 'Server is running',
    database: DATABASE_NAME,
    collection: COLLECTION_NAME
  });
});

// Debug endpoint to list all users and their fields
app.get('/api/debug-users', async (req, res) => {
  try {
    const users = await db.collection(COLLECTION_NAME).find({}).toArray();
    
    const userInfo = users.map(user => ({
      _id: user._id,
      email: user.email,
      username: user.username || 'NO_USERNAME',
      studentId: user.studentId || 'NO_STUDENT_ID',
      name: user.name || 'NO_NAME',
      fields: Object.keys(user)
    }));
    
    res.json({
      success: true,
      count: users.length,
      users: userInfo,
      message: 'If users show NO_USERNAME, then username field does not exist in database'
    });
    
  } catch (error) {
    console.error('Debug users error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Face image upload endpoint - supports multiple angles
app.post('/api/upload-face', upload.single('face_image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No image file provided'
      });
    }

    const { userId, imageType = 'face_capture', stepName, stepNumber } = req.body;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: 'User ID is required'
      });
    }

    console.log('Uploading face image for user:', userId);
    console.log('Image size:', req.file.size);
    console.log('Image type:', req.file.mimetype);
    console.log('Step name:', stepName);
    console.log('Step number:', stepNumber);

    // First, get the user's role from the database
    const user = await db.collection(COLLECTION_NAME).findOne(
      { _id: new ObjectId(userId) },
      { projection: { role: 1 } }
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Get user's role, default to 'user' if not specified
    const userRole = user.role || 'user';
    console.log('User role:', userRole);

    // Create a more descriptive public_id that includes the angle/step
    const publicIdSuffix = stepName ? 
      `${stepName.toLowerCase().replace(/\s+/g, '_')}_${Date.now()}` : 
      `${imageType}_${Date.now()}`;

    // Upload to Cloudinary with user-specific folder structure based on role
    const uploadResult = await new Promise((resolve, reject) => {
              cloudinary.uploader.upload_stream(
          {
            resource_type: 'image',
            folder: `eduvision/facedata/${userRole}/${userId}`,
            public_id: publicIdSuffix,
          overwrite: false, // Don't overwrite to keep all angles
          transformation: [
            { quality: '100' },
            { fetch_format: 'auto' }
          ],
          tags: [`user_${userId}`, `step_${stepNumber}`, stepName || 'face_capture'],
          context: {
            user_id: userId,
            step_name: stepName || '',
            step_number: stepNumber || '',
            upload_type: 'face_registration'
          }
        },
        (error, result) => {
          if (error) {
            reject(error);
          } else {
            resolve(result);
          }
        }
      ).end(req.file.buffer);
    });

    // Create image data object with angle/step information
    const imageData = {
      cloudinary_id: uploadResult.public_id,
      url: uploadResult.secure_url,
      uploaded_at: new Date(),
      image_type: imageType,
      step_name: stepName || '',
      step_number: stepNumber || 0,
      metadata: {
        width: uploadResult.width,
        height: uploadResult.height,
        format: uploadResult.format,
        tags: uploadResult.tags
      }
    };

    // Update user with face images array (push to array instead of replacing)
    const result = await db.collection(COLLECTION_NAME).updateOne(
      { _id: new ObjectId(userId) },
      { 
        $push: { 
          face_images: imageData  // Store in array
        },
        $set: {
          face_image_url: uploadResult.secure_url, // Keep for backward compatibility
          last_face_upload: new Date()
        }
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    console.log('Face image uploaded successfully:', uploadResult.secure_url);
    console.log('Stored with step:', stepName, 'number:', stepNumber);

    res.json({
      success: true,
      message: 'Face image uploaded successfully',
      image_url: uploadResult.secure_url,
      cloudinary_id: uploadResult.public_id,
      step_name: stepName,
      step_number: stepNumber
    });

  } catch (error) {
    console.error('Face upload error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to upload face image: ' + error.message
    });
  }
});

// Get user face images endpoint - returns all face images
app.get('/api/user-faces/:userId', async (req, res) => {
  try {
    const { userId } = req.params;

    const user = await db.collection(COLLECTION_NAME).findOne(
      { _id: new ObjectId(userId) },
      { projection: { face_images: 1, face_image: 1, face_image_url: 1 } }
    );

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    res.json({
      success: true,
      face_images: user.face_images || [],  // Return array of all face images
      face_image: user.face_image || null,  // Keep for backward compatibility
      face_image_url: user.face_image_url || null
    });

  } catch (error) {
    console.error('Get user faces error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Clear face images endpoint - use when starting new registration
app.delete('/api/user-faces/:userId/clear', async (req, res) => {
  try {
    const { userId } = req.params;

    // Clear the face_images array for the user
    const result = await db.collection(COLLECTION_NAME).updateOne(
      { _id: new ObjectId(userId) },
      { 
        $set: { 
          face_images: [],  // Clear the array
          face_registration_cleared_at: new Date()
        }
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    console.log('Face images cleared for user:', userId);

    res.json({
      success: true,
      message: 'Face images cleared successfully'
    });

  } catch (error) {
    console.error('Clear face images error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to clear face images: ' + error.message
    });
  }
});

// Complete face registration - save all angles and mark registration as complete
app.post('/api/complete-face-registration', async (req, res) => {
  try {
    const { userId, registrationData } = req.body;

    if (!userId) {
      return res.status(400).json({
        success: false,
        message: 'User ID is required'
      });
    }

    // Update user with complete registration data
    const result = await db.collection(COLLECTION_NAME).updateOne(
      { _id: new ObjectId(userId) },
      { 
        $set: { 
          face_registration_complete: true,
          face_registration_completed_at: new Date(),
          face_registration_data: registrationData || {},
          face_registration_steps_count: registrationData?.stepsCompleted || 0
        }
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    console.log('Face registration completed for user:', userId);
    console.log('Steps completed:', registrationData?.stepsCompleted || 0);

    res.json({
      success: true,
      message: 'Face registration completed successfully'
    });

  } catch (error) {
    console.error('Complete registration error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to complete registration: ' + error.message
    });
  }
});

// Debug endpoint to check password hashing method
app.post('/api/debug-password', async (req, res) => {
  try {
    const { email } = req.body;
    
    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email is required'
      });
    }

    const user = await db.collection(COLLECTION_NAME).findOne({ email });
    
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    const password = user.password;
    let hashingMethod = 'unknown';
    
    if (password.startsWith('$2a$') || password.startsWith('$2b$') || password.startsWith('$2y$')) {
      hashingMethod = 'bcrypt';
    } else if (password.length === 32 && /^[a-f0-9]+$/i.test(password)) {
      hashingMethod = 'MD5';
    } else if (password.length === 64 && /^[a-f0-9]+$/i.test(password)) {
      hashingMethod = 'SHA256';
    } else if (password.length === 40 && /^[a-f0-9]+$/i.test(password)) {
      hashingMethod = 'SHA1';
    } else {
      hashingMethod = 'plain text or unknown';
    }

    res.json({
      success: true,
      email: email,
      passwordLength: password.length,
      hashingMethod: hashingMethod,
      passwordSample: password.substring(0, 10) + '...' // Only show first 10 chars for security
    });

  } catch (error) {
    console.error('Debug password error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Password verification function - handles multiple hashing methods
async function verifyPassword(plainPassword, hashedPassword) {
  try {
    // Method 1: Check if it's bcrypt (starts with $2a$, $2b$, or $2y$)
    if (hashedPassword.startsWith('$2a$') || hashedPassword.startsWith('$2b$') || hashedPassword.startsWith('$2y$')) {
      console.log('Verifying bcrypt password');
      return await bcrypt.compare(plainPassword, hashedPassword);
    }
    
    // Method 2: Check if it's MD5 (32 characters hex)
    if (hashedPassword.length === 32 && /^[a-f0-9]+$/i.test(hashedPassword)) {
      console.log('Verifying MD5 password');
      const md5Hash = crypto.createHash('md5').update(plainPassword).digest('hex');
      return md5Hash.toLowerCase() === hashedPassword.toLowerCase();
    }
    
    // Method 3: Check if it's SHA256 (64 characters hex)
    if (hashedPassword.length === 64 && /^[a-f0-9]+$/i.test(hashedPassword)) {
      console.log('Verifying SHA256 password');
      const sha256Hash = crypto.createHash('sha256').update(plainPassword).digest('hex');
      return sha256Hash.toLowerCase() === hashedPassword.toLowerCase();
    }
    
    // Method 4: Check if it's SHA1 (40 characters hex)
    if (hashedPassword.length === 40 && /^[a-f0-9]+$/i.test(hashedPassword)) {
      console.log('Verifying SHA1 password');
      const sha1Hash = crypto.createHash('sha1').update(plainPassword).digest('hex');
      return sha1Hash.toLowerCase() === hashedPassword.toLowerCase();
    }
    
    // Method 5: Try as plain text (not recommended)
    console.log('Verifying plain text password');
    return plainPassword === hashedPassword;
    
  } catch (error) {
    console.error('Password verification error:', error);
    return false;
  }
}

// Simple token generation (replace with proper JWT in production)
function generateToken(userId) {
  return `token_${userId}_${Date.now()}`;
}

app.listen(port, '0.0.0.0', () => {
  console.log(`Server running at http://localhost:${port}`);
  console.log(`Server also accessible at http://0.0.0.0:${port}`);
  console.log(`Database: ${DATABASE_NAME}`);
  console.log(`Collection: ${COLLECTION_NAME}`);
  console.log(`\nTo access from your phone:`);
  console.log(`1. Find your computer's IP address (ipconfig on Windows)`);
  console.log(`2. Use http://YOUR_COMPUTER_IP:${port} in the app`);
});

// Superadmin endpoints
app.get('/api/superadmin/deans', async (req, res) => {
  try {
    const deans = await db.collection(COLLECTION_NAME).find({ role: 'dean' }).toArray();
    res.json(deans);
  } catch (error) {
    console.error('Error fetching deans:', error);
    res.status(500).json({ error: 'Failed to fetch deans' });
  }
});

app.get('/api/superadmin/instructors', async (req, res) => {
  try {
    const instructors = await db.collection(COLLECTION_NAME).find({ role: 'instructor' }).toArray();
    res.json(instructors);
  } catch (error) {
    console.error('Error fetching instructors:', error);
    res.status(500).json({ error: 'Failed to fetch instructors' });
  }
});

app.get('/api/superadmin/program-chairs', async (req, res) => {
  try {
    const programChairs = await db.collection(COLLECTION_NAME).find({ role: 'programChairperson' }).toArray();
    res.json(programChairs);
  } catch (error) {
    console.error('Error fetching program chairs:', error);
    res.status(500).json({ error: 'Failed to fetch program chairs' });
  }
});

app.get('/api/superadmin/pending-deans', async (req, res) => {
  try {
    const pendingDeans = await db.collection(COLLECTION_NAME).find({ 
      role: 'dean', 
      status: 'pending' 
    }).toArray();
    res.json(pendingDeans);
  } catch (error) {
    console.error('Error fetching pending deans:', error);
    res.status(500).json({ error: 'Failed to fetch pending deans' });
  }
});

app.get('/api/superadmin/pending-instructors', async (req, res) => {
  try {
    const pendingInstructors = await db.collection(COLLECTION_NAME).find({ 
      role: 'instructor', 
      status: 'pending' 
    }).toArray();
    res.json(pendingInstructors);
  } catch (error) {
    console.error('Error fetching pending instructors:', error);
    res.status(500).json({ error: 'Failed to fetch pending instructors' });
  }
});

app.get('/api/superadmin/pending-program-chairs', async (req, res) => {
  try {
    const pendingProgramChairs = await db.collection(COLLECTION_NAME).find({ 
      role: 'programChairperson', 
      status: 'pending' 
    }).toArray();
    res.json(pendingProgramChairs);
  } catch (error) {
    console.error('Error fetching pending program chairs:', error);
    res.status(500).json({ error: 'Failed to fetch pending program chairs' });
  }
});

// To run this server:
// 1. npm init -y
// 2. npm install express mongodb cors bcrypt
// 3. node server.js