const express = require('express');
const cors = require('cors');
const AWS = require('aws-sdk');
const app = express();

// AWS DynamoDB yapılandırması
const dynamoDB = new AWS.DynamoDB.DocumentClient({
  region: process.env.AWS_REGION || 'eu-central-1'
});

app.use(cors());
app.use(express.json());

// Todo'ları getir
app.get('/todos', async (req, res) => {
  const params = {
    TableName: 'Todos'
  };
  
  try {
    const data = await dynamoDB.scan(params).promise();
    res.json(data.Items);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Yeni todo ekle
app.post('/todos', async (req, res) => {
  const params = {
    TableName: 'Todos',
    Item: {
      id: Date.now().toString(),
      title: req.body.title,
      completed: false,
      createdAt: new Date().toISOString()
    }
  };

  try {
    await dynamoDB.put(params).promise();
    res.json(params.Item);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Server ${PORT} portunda çalışıyor`);
}); 