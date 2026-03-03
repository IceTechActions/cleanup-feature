const Redis = require('ioredis');
const { execSync } = require('child_process');

// Get KeyVault name and prefix from command line arguments
const keyVaultName = process.argv[2];
const pattern = process.argv[3];

if (!keyVaultName || !pattern) {
    console.error('Please provide KeyVault name and Redis prefix as arguments');
    process.exit(1);
}

// Get Redis connection string from KeyVault
let redisConnectionString;
try {
    redisConnectionString = execSync(
        `az keyvault secret show --vault-name "${keyVaultName}" --name "Global-Redis-ConnectionString" --query "value" -o tsv`
    ).toString().trim();
} catch (error) {
    console.error('Failed to get Redis connection string from KeyVault:', error.message);
    process.exit(1);
}

// Parse connection string
const host = redisConnectionString.split(':')[0];
const password = redisConnectionString.match(/password=([^,]*)/)[1];
const maskedPassword = password.substring(0, 3) + '*'.repeat(password.length - 3);
console.log('Attempting to connect to Redis host:', host);
console.log('Using password starting with:', maskedPassword);

const redis = new Redis({
    port: 6380,
    host: host,
    password: password,
    db: 0,
    tls: {
        rejectUnauthorized: false,
        minVersion: 'TLSv1.2',
        maxVersion: 'TLSv1.2'
    },
});

// First, check if we're connected to Redis
redis.ping((err, result) => {
    if (err) {
        console.error('Error pinging Redis:', err);
        process.exit(1);
    }
    console.log('Successfully connected to Redis:', result);

    // If we're connected, then we can start scanning for keys
    const getAllKeys = (pattern) => {
        return new Promise((resolve, reject) => {
            let keysArray = [];
            let stream = redis.scanStream({
                match: `${pattern}:*`
            });

            stream.on('data', (keys = []) => {
                for (let key of keys) {
                    if (!keysArray.includes(key)) {
                        keysArray.push(key);
                    }
                }
            });

            stream.on('end', () => {
                resolve(keysArray);
            });

            stream.on('error', (error) => {
                reject(error);
            });
        });
    };

    getAllKeys(pattern)
        .then((keysArray) => {
            console.log(`Found keys for prefix '${pattern}':`, keysArray);

            // Deleting keys
            return Promise.all(keysArray.map(key => redis.del(key)))
                .then(() => {
                    console.log(`Successfully deleted all keys with prefix '${pattern}'`);
                    redis.quit();
                })
                .catch((error) => {
                    console.error('Error deleting keys:', error);
                    redis.quit();
                    process.exit(1);
                });
        })
        .catch((error) => {
            console.error('Error getting keys:', error);
            redis.quit();
            process.exit(1);
        });
});
