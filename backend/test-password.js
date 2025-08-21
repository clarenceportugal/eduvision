const crypto = require('crypto');
const bcrypt = require('bcrypt');

// Test different hashing methods
async function testPasswordHashing() {
  const testPassword = 'password123';
  
  console.log('=== PASSWORD HASHING TEST ===');
  console.log(`Original password: ${testPassword}\n`);
  
  // 1. Plain text
  console.log('1. Plain Text:');
  console.log(`   Result: ${testPassword}`);
  console.log(`   Length: ${testPassword.length} characters\n`);
  
  // 2. MD5
  const md5Hash = crypto.createHash('md5').update(testPassword).digest('hex');
  console.log('2. MD5:');
  console.log(`   Result: ${md5Hash}`);
  console.log(`   Length: ${md5Hash.length} characters\n`);
  
  // 3. SHA1
  const sha1Hash = crypto.createHash('sha1').update(testPassword).digest('hex');
  console.log('3. SHA1:');
  console.log(`   Result: ${sha1Hash}`);
  console.log(`   Length: ${sha1Hash.length} characters\n`);
  
  // 4. SHA256
  const sha256Hash = crypto.createHash('sha256').update(testPassword).digest('hex');
  console.log('4. SHA256:');
  console.log(`   Result: ${sha256Hash}`);
  console.log(`   Length: ${sha256Hash.length} characters\n`);
  
  // 5. bcrypt
  const bcryptHash = await bcrypt.hash(testPassword, 10);
  console.log('5. bcrypt:');
  console.log(`   Result: ${bcryptHash}`);
  console.log(`   Length: ${bcryptHash.length} characters\n`);
  
  console.log('=== IDENTIFICATION GUIDE ===');
  console.log('- Plain text: Variable length, readable text');
  console.log('- MD5: Exactly 32 hex characters');
  console.log('- SHA1: Exactly 40 hex characters');
  console.log('- SHA256: Exactly 64 hex characters');
  console.log('- bcrypt: Starts with $2a$, $2b$, or $2y$');
}

// Run the test
testPasswordHashing().catch(console.error);

console.log('\n=== HOW TO USE ===');
console.log('1. Check your MongoDB database password field');
console.log('2. Compare with the formats above');
console.log('3. The server will automatically detect the method');
console.log('4. Run the server: npm start');
console.log('5. Test login with actual credentials from your database\n');