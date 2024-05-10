const express = require("express")

const app = express()
const port = process.env.PORT || 8080

app.get("/", (req, res) => {
    res.status(200).json({
        message: "API Express"
    })
})

app.listen(port, () => console.log(`Server is running on port ${port}`));
