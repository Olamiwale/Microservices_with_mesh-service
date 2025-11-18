const express = require("express");
const app = express();

app.use(express.json());

app.get("/", (req, res) => {
  res.send("Welcome, User Service");
});


app.get("/user-orders", async (req, res) => {
  try {
    const response = await fetch("http://order-service.k8s.svc.cluster.local/orders");
    const orders = await response.json();
    res.json({ user: "John", orders });
  } catch (error) {
    res.status(500).json({ error: "Failed to fetch orders" });
  }
});

app.listen(3000, () => {
  console.log("Server is working on port 3000");
});