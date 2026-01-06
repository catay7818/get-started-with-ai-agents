import fastapi
from fastapi.responses import JSONResponse

router = fastapi.APIRouter()


@router.get("/mcp_demo", operation_id="mcp_demo")
def mcp_demo():
    return JSONResponse({"message": "YES"})
