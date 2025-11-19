const express = require("express");
const app = express();

app.use(express.json());

app.get("/", (req, res) => {
  res.send("Welcome, User Service");
});


app.get("/orders", async (req, res) => {
  try {
    const response = await fetch("http://order-service/");
    const data = await response.text();
    res.json({ 
      user: "John", 
      orderServiceResponse: data 
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});


app.listen(3000, () => {
  console.log("Server is working on port 3000");
}); 

