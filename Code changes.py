import pytest
from unittest.mock import patch, MagicMock
from os.path import basename
import sys

from your_module import DataPuller, main  # Replace 'your_module' with the actual module
from your_module.snowflake_client import SnowflakeClient  # Adjust import paths as needed


@pytest.fixture
def mock_sg():
    """Mock for StorageGrid configuration."""
    mock_sg = MagicMock()
    mock_sg.write_dataframe.return_value = True  # Simulating a successful write operation
    return mock_sg


def test_data_write_from_storagegrid(mock_sg):
    """Test data writing using StorageGrid configuration."""
    with patch.object(DataPuller, "snf_client", mock_sg), patch.object(
        DataPuller, "write_dataframe", MagicMock()
    ) as mock_write_dataframe, pytest.raises(ValueError):
        main(data_pull=DataPuller())

        # Ensure the StorageGrid write function is called
        mock_sg.write_dataframe.assert_called_once()

    with patch.object(sys, "argv", [basename(__file__), "--lob", "HO"]), patch.object(
        SnowflakeClient, "__init__", return_value=None
    ), patch.object(DataPuller, "storagegrid_config", mock_sg):
        data_pull = DataPuller()

        # Simulating data writing
        data_pull.snf_client.write_dataframe("sample_dataframe")

        # Ensure data write is invoked
        mock_sg.write_dataframe.assert_called_with("sample_dataframe")
