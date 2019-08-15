const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 8080;
// Rate limiting sederhana (Pindahkan ke ATAS)
const uploadCounts = new Map();
const MAX_UPLOADS_PER_HOUR = 100;

// Middleware logging (Pindahkan ke ATAS sebelum routes)
const logUploadMiddleware = (req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} from ${req.ip}`);
  next();
};

// Middleware rate limiting
const rateLimitMiddleware = (req, res, next) => {
  const ip = req.ip;
  const now = Date.now();
  const oneHourAgo = now - 3600000;
  
  if (!uploadCounts.has(ip)) {
    uploadCounts.set(ip, []);
  }
  
  const userUploads = uploadCounts.get(ip).filter(time => time > oneHourAgo);
  
  if (userUploads.length >= MAX_UPLOADS_PER_HOUR) {
    return res.status(429).json({ 
      success: false, 
      error: 'Upload limit exceeded. Max 100 files per hour.' 
    });
  }
  
  next();
};

// Global middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static('public'));
app.use(logUploadMiddleware); // Log semua request

// Konfigurasi penyimpanan file
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    // Ganti 'uploads/' dengan 'storage/' sesuai permintaan
    const uploadDir = 'storage/';
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    // Preserve struktur folder jika ada
    let filePath = '';
    if (req.body.path) {
      // Buat struktur folder berdasarkan path
      const dirPath = path.join('storage/', path.dirname(req.body.path));
      if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
      }
      filePath = req.body.path;
    } else {
      // Hapus karakter khusus dan spasi
      const originalName = file.originalname;
      const safeName = originalName.replace(/[^a-zA-Z0-9._-]/g, '_');
      const timestamp = Date.now();
      filePath = `${timestamp}_${safeName}`;
    }
    cb(null, filePath);
  }
});

// Filter file (opsional - lebih longgar untuk testing)
const fileFilter = (req, file, cb) => {
  // Izinkan semua file type untuk testing
  // Atau sesuaikan dengan kebutuhan
  const disallowedTypes = [
    'application/x-msdownload', // .exe
    'application/x-dosexec',    // .exe
    'application/x-sh',         // shell script
    'application/x-msdos-program'
  ];
  
  if (disallowedTypes.includes(file.mimetype)) {
    cb(new Error('File type not allowed for security reasons'), false);
  } else {
    cb(null, true);
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 500 * 1024 * 1024, // 500MB max (sesuaikan)
    files: 50 // Max 50 files sekaligus
  }
});

// =============== ROUTES ===============

// Home route
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    uploadsDir: path.join(__dirname, 'storage'),
    diskUsage: getDiskUsage()
  });
});

// Upload single file (dengan rate limiting)
app.post('/api/upload', rateLimitMiddleware, upload.single('file'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ 
        success: false, 
        error: 'No file uploaded' 
      });
    }

    // Update rate limiting counter
    const ip = req.ip;
    if (!uploadCounts.has(ip)) {
      uploadCounts.set(ip, []);
    }
    uploadCounts.get(ip).push(Date.now());

    // Simpan informasi file
    const fileInfo = {
      id: Date.now(),
      name: req.file.originalname,
      filename: req.file.filename,
      path: `/storage/${req.file.filename}`,
      fullPath: req.file.path,
      size: req.file.size,
      mimetype: req.file.mimetype,
      uploadedAt: new Date().toISOString(),
      ip: req.ip
    };

    console.log(`✓ File uploaded: ${fileInfo.name} (${fileInfo.size} bytes)`);

    res.json({
      success: true,
      message: 'File uploaded successfully',
      file: fileInfo
    });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Upload failed', 
      details: error.message 
    });
  }
});

// Upload multiple files (dengan rate limiting)
app.post('/api/upload-multiple', rateLimitMiddleware, upload.array('files', 50), (req, res) => {
  try {
    if (!req.files || req.files.length === 0) {
      return res.status(400).json({ 
        success: false, 
        error: 'No files uploaded' 
      });
    }

    // Update rate limiting counter (hitung sekali untuk batch)
    const ip = req.ip;
    if (!uploadCounts.has(ip)) {
      uploadCounts.set(ip, []);
    }
    uploadCounts.get(ip).push(Date.now());

    const filesInfo = req.files.map(file => ({
      id: Date.now() + Math.random(),
      name: file.originalname,
      filename: file.filename,
      path: `/storage/${file.filename}`,
      fullPath: file.path,
      size: file.size,
      mimetype: file.mimetype,
      uploadedAt: new Date().toISOString(),
      ip: req.ip
    }));

    console.log(`✓ ${req.files.length} files uploaded by ${req.ip}`);

    res.json({
      success: true,
      message: `${req.files.length} files uploaded successfully`,
      files: filesInfo,
      totalSize: filesInfo.reduce((sum, f) => sum + f.size, 0)
    });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Upload failed', 
      details: error.message 
    });
  }
});

// Get list of uploaded files dengan struktur folder
app.get('/api/files', (req, res) => {
  try {
    const storageDir = 'storage/';
    
    if (!fs.existsSync(storageDir)) {
      return res.json({ 
        success: true, 
        files: [],
        totalSize: 0,
        totalFiles: 0 
      });
    }

    const getAllFiles = (dir, baseDir = '') => {
      let results = [];
      const items = fs.readdirSync(dir);
      
      items.forEach(item => {
        const fullPath = path.join(dir, item);
        const relativePath = baseDir ? path.join(baseDir, item) : item;
        const stats = fs.statSync(fullPath);
        
        if (stats.isDirectory()) {
          // Rekursif untuk subfolder
          results = results.concat(getAllFiles(fullPath, relativePath));
        } else {
          results.push({
            name: item,
            filename: relativePath,
            path: `/storage/${relativePath}`,
            fullPath: fullPath,
            size: stats.size,
            uploadedAt: stats.mtime,
            isDirectory: false
          });
        }
      });
      
      return results;
    };

    const files = getAllFiles(storageDir);
    const totalSize = files.reduce((sum, f) => sum + f.size, 0);

    res.json({ 
      success: true, 
      files,
      totalSize,
      totalFiles: files.length,
      storagePath: path.resolve(storageDir)
    });
  } catch (error) {
    console.error('Error reading files:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to read files' 
    });
  }
});

// Delete file
app.delete('/api/files/:filename', (req, res) => {
  try {
    const filename = decodeURIComponent(req.params.filename);
    const filePath = path.join('storage/', filename);

    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ 
        success: false, 
        error: 'File not found' 
      });
    }

    // Cek apakah itu file atau folder
    const stats = fs.statSync(filePath);
    
    if (stats.isDirectory()) {
      // Hapus folder rekursif
      fs.rmSync(filePath, { recursive: true, force: true });
      console.log(`🗑️ Folder deleted: ${filename}`);
    } else {
      // Hapus file
      fs.unlinkSync(filePath);
      console.log(`🗑️ File deleted: ${filename}`);
    }

    res.json({ 
      success: true, 
      message: 'Deleted successfully',
      deleted: filename
    });
  } catch (error) {
    console.error('Delete error:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Delete failed',
      details: error.message 
    });
  }
});

// Get file info
app.get('/api/files/info/:filename', (req, res) => {
  try {
    const filename = decodeURIComponent(req.params.filename);
    const filePath = path.join('storage/', filename);

    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ 
        success: false, 
        error: 'File not found' 
      });
    }

    const stats = fs.statSync(filePath);
    const fileInfo = {
      name: path.basename(filename),
      filename: filename,
      path: `/storage/${filename}`,
      fullPath: filePath,
      size: stats.size,
      isDirectory: stats.isDirectory(),
      created: stats.birthtime,
      modified: stats.mtime,
      accessed: stats.atime,
      permissions: (stats.mode & parseInt('777', 8)).toString(8)
    };

    res.json({ 
      success: true, 
      file: fileInfo 
    });
  } catch (error) {
    console.error('File info error:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to get file info' 
    });
  }
});

// Create directory
app.post('/api/directory', (req, res) => {
  try {
    const { path: dirPath } = req.body;
    
    if (!dirPath) {
      return res.status(400).json({ 
        success: false, 
        error: 'Directory path is required' 
      });
    }

    const fullPath = path.join('storage/', dirPath);
    
    if (fs.existsSync(fullPath)) {
      return res.status(400).json({ 
        success: false, 
        error: 'Directory already exists' 
      });
    }

    fs.mkdirSync(fullPath, { recursive: true });
    
    res.json({ 
      success: true, 
      message: 'Directory created successfully',
      path: dirPath
    });
  } catch (error) {
    console.error('Create directory error:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to create directory' 
    });
  }
});

// Serve uploaded files statically
app.use('/storage', express.static('storage', {
  setHeaders: (res, filePath) => {
    // Set security headers
    res.set('X-Content-Type-Options', 'nosniff');
    
    // Untuk file yang bisa dieksekusi, set header yang aman
    if (filePath.endsWith('.html') || filePath.endsWith('.htm')) {
      res.set('Content-Type', 'text/html');
    }
  }
}));

// 404 handler
app.use((req, res) => {
  res.status(404).json({ 
    success: false, 
    error: 'Route not found',
    path: req.url 
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ 
        success: false, 
        error: 'File too large (max 500MB)' 
      });
    }
    if (err.code === 'LIMIT_FILE_COUNT') {
      return res.status(400).json({ 
        success: false, 
        error: 'Too many files (max 50 per batch)' 
      });
    }
    return res.status(400).json({ 
      success: false, 
      error: err.message 
    });
  }
  
  res.status(500).json({ 
    success: false, 
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// Helper function untuk disk usage
function getDiskUsage() {
  try {
    const storageDir = 'storage/';
    if (!fs.existsSync(storageDir)) return { used: 0, total: 'N/A' };
    
    let totalSize = 0;
    const getAllSizes = (dir) => {
      const items = fs.readdirSync(dir);
      items.forEach(item => {
        const fullPath = path.join(dir, item);
        const stats = fs.statSync(fullPath);
        if (stats.isDirectory()) {
          getAllSizes(fullPath);
        } else {
          totalSize += stats.size;
        }
      });
    };
    
    getAllSizes(storageDir);
    
    return {
      used: totalSize,
      usedFormatted: formatBytes(totalSize),
      files: countFiles(storageDir),
      lastCleaned: getLastModified(storageDir)
    };
  } catch (error) {
    return { error: error.message };
  }
}

function formatBytes(bytes, decimals = 2) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

function countFiles(dir) {
  let count = 0;
  if (!fs.existsSync(dir)) return 0;
  
  const items = fs.readdirSync(dir);
  items.forEach(item => {
    const fullPath = path.join(dir, item);
    if (fs.statSync(fullPath).isDirectory()) {
      count += countFiles(fullPath);
    } else {
      count++;
    }
  });
  return count;
}

function getLastModified(dir) {
  if (!fs.existsSync(dir)) return null;
  const stats = fs.statSync(dir);
  return stats.mtime;
}

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`📁 Upload folder: ${path.join(__dirname, 'storage')}`);
  console.log(`🌐 Access URLs:`);
  console.log(`   Local:  http://localhost:${PORT}`);
  console.log(`   Network: http://YOUR_IP:${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`🔒 Rate limiting: ${MAX_UPLOADS_PER_HOUR} files/hour per IP`);
  
  // Buat folder storage jika belum ada
  if (!fs.existsSync('storage')) {
    fs.mkdirSync('storage', { recursive: true });
    console.log(`📂 Created storage directory`);
  }
});
