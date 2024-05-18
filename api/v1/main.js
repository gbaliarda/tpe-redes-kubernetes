const express = require("express")
const bodyParser = require("body-parser");
const { Pool } = require("pg");
require('dotenv').config();

const app = express()
const port = process.env.PORT || 8080

app.use(bodyParser.json());

const pool = new Pool({
    user: process.env.DB_USER,
    host: process.env.DB_HOST,
    database: process.env.DB_NAME,
    password: process.env.DB_PASS,
    port: 5432,
});

app.post("/user", async (req, res) => {
    const { username, password } = req.body;
  
    if (!username || !password) {
      return res
        .status(400)
        .json({ message: "Se requieren tanto el nombre de usuario como la contraseña." });
    }
  
    try {
      const query = "INSERT INTO users (username, password) VALUES ($1, $2) RETURNING *";
      const values = [username, password];
      const result = await pool.query(query, values);
      const newUser = result.rows[0];
  
      return res.status(201).json(newUser);
    } catch (error) {
      console.error("Error al crear usuario:", error);
      return res.status(500).json({ message: "Error al crear usuario." });
    }
});

app.get("/user/:id", async (req, res) => {
    const userId = parseInt(req.params.id);
  
    try {
      const query = "SELECT * FROM users WHERE id = $1";
      const result = await pool.query(query, [userId]);
      const user = result.rows[0];
  
      if (!user) {
        return res.status(404).json({ message: "Usuario no encontrado." });
      }
  
      return res.status(200).json(user);
    } catch (error) {
      console.error("Error al obtener usuario:", error);
      return res.status(500).json({ message: "Error al obtener usuario." });
    }
});

app.get("/", (req, res) => {
    res.status(200).json({
        message: "API Express V1"
    })
})

app.listen(port, () => console.log(`Server is running on port ${port}`));
